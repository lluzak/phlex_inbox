# Live Components

Live Components is a system for building real-time, reactive UI components in Rails. It works by compiling ERB templates to JavaScript at boot time, then using ActionCable to push JSON data updates to the client, where the compiled JS re-renders the component without a server round-trip.

The key insight: **one ERB template serves both server-side initial rendering (standard ViewComponent) and client-side re-rendering (compiled JavaScript)**. No template duplication.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  Server                                                 │
│                                                         │
│  ERB Template ──► Ruby2JS Compiler ──► JS Function      │
│       │                                    │            │
│       ▼                                    ▼            │
│  ViewComponent         Base64-encoded JS embedded       │
│  renders HTML          in data-* attributes             │
│       │                                                 │
│  Model update ──► build_data() ──► JSON over ActionCable│
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│  Client (Browser)                                       │
│                                                         │
│  Stimulus controller decodes JS template                │
│       │                                                 │
│  ActionCable receives JSON data                         │
│       │                                                 │
│  Compiled JS function(data) ──► HTML string             │
│       │                                                 │
│  Idiomorph morphs DOM                                   │
└─────────────────────────────────────────────────────────┘
```

## Making a Component Live

Include `LiveComponent` and declare the model, stream, and actions:

```ruby
class MessageRowComponent < ApplicationComponent
  include LiveComponent

  subscribes_to :message
  broadcasts stream: ->(message) { [message.recipient, :messages] },
             prepend_target: "message_items"
  live_action :toggle_star

  def initialize(message:, selected: false)
    @message = message
    @selected = selected
  end

  private

  def toggle_star
    @message.toggle_starred!
  end
end
```

### DSL Methods

| Method | Purpose |
|---|---|
| `subscribes_to :attr` | Names the model attribute (e.g., `:message` means `@message`) |
| `broadcasts stream:, prepend_target:` | Configures the ActionCable stream and where to prepend new records |
| `live_action :name, params: []` | Registers a server-side action callable from the client |

### Model Setup

Include `Broadcastable` and register which component classes should broadcast:

```ruby
class Message < ApplicationRecord
  include Broadcastable

  broadcasts_with MessageRowComponent, MessageDetailComponent, MessageLabelsComponent
end
```

This hooks into ActiveRecord lifecycle callbacks:
- `after_create_commit` — prepends server-rendered HTML via Turbo Streams
- `after_update_commit` — broadcasts JSON data via `LiveComponentChannel`
- `after_destroy_commit` — broadcasts a destroy action

## Lifecycle

### 1. Initial Server Render

When a component renders, `LiveComponent` overrides `render_in` to wrap the output in a `<div>` with data attributes:

```html
<div id="message_42"
     data-controller="live-renderer"
     data-live-renderer-template-value="<base64-encoded JS>"
     data-live-renderer-stream-value="<signed stream name>"
     data-live-renderer-action-url-value="/live_component_actions"
     data-live-renderer-action-token-value="<signed token>"
     data-live-renderer-state-value='{"selected":false}'
     data-live-renderer-data-value='{"v0":"Alice",...}'>
  <!-- normal ViewComponent HTML -->
</div>
```

The last two attributes are only present when the component declares `client_state` fields.

### 2. Client Connects

The `live_renderer_controller` Stimulus controller:
1. Decodes the base64 template and compiles it via `new Function("data", body)`
2. Subscribes to the ActionCable stream (multiple elements on the same stream share one subscription)

### 3. Server-Side State Change

When a model updates:
1. `after_update_commit` fires `broadcast_live_update`
2. For each registered component class, `build_data(record)` evaluates all extracted Ruby expressions against the current record state
3. The resulting JSON hash is broadcast over `LiveComponentChannel`

### 4. Client Re-Renders

1. The Stimulus controller receives the JSON message
2. If `data.dom_id` matches the element's ID, the compiled JS function runs with the data
3. The resulting HTML is morphed into the DOM using Idiomorph (preserves focus, scroll, etc.)

### 5. Actions

Buttons can trigger server-side actions without a page reload:

```erb
<button data-action="click->live-renderer#performAction"
        data-live-renderer-action-param="toggle_star">
  Star
</button>
```

This POSTs to `/live_component_actions` with a signed token. The controller verifies the token, instantiates the component, and calls the action method. The model update then triggers a broadcast to all subscribed clients.

## Client State

Live components can declare client-side state fields that survive server-triggered re-renders and can be updated purely from JavaScript.

### Declaring Client State

```ruby
class MessageRowComponent < ApplicationComponent
  include LiveComponent
  subscribes_to :message

  client_state :selected, default: false

  def initialize(message:, selected: false)
    @message = message
    @selected = selected
  end
end
```

The `client_state :name, default:` DSL registers a field. The ERB template uses `@selected` normally — no special syntax.

### How It Works

1. **Initial render**: The wrapper `<div>` includes two extra data attributes:
   - `data-live-renderer-state-value='{"selected":false}'` — the client state
   - `data-live-renderer-data-value='{"v0":"Alice",...}'` — the initial server data

2. **Client connect**: The Stimulus controller reads both, storing `clientState` and `lastServerData` in memory.

3. **Server update**: When ActionCable pushes new data, the controller merges it with client state before rendering: `{ ...serverData, ...clientState }`. Client state wins, so `selected` is preserved.

4. **Client state change**: The `setState` Stimulus action updates `clientState` and re-renders with the last known server data.

### Updating Client State

Use the `setState` Stimulus action:

```erb
<a data-action="click->live-renderer#setState"
   data-live-renderer-selected-param="true">
  Click me
</a>
```

Stimulus params are merged into `clientState`. The component re-renders immediately if server data is available.

### Multiple State Fields

Components can declare multiple client state fields:

```ruby
client_state :selected, default: false
client_state :expanded, default: false
```

Each is independently tracked and merged into the render data.

## ERB-to-JavaScript Compilation

The compiler converts a single ERB template into a JavaScript function that produces the same HTML given a data object.

### Pipeline

```
ERB source
    │
    ▼
Ruby2JS::Erubi     ──► Ruby buffer code (_buf += @message.subject.to_s)
    │
    ▼
Ruby2JS.convert    ──► JavaScript (with ErbExtractor filter)
    │
    ▼
Compiler           ──► Adds _escape(), _tag() helpers, destructuring, escaping
    │
    ▼
Base64-encoded JS embedded in HTML
```

### The Extraction Pattern

The central idea: ERB expressions fall into two categories:

1. **Server-only expressions** — instance variable chains (`@message.subject`), constants (`Label.order(:name)`), helper methods referencing ivars (`time_ago_in_words(@message.created_at)`)
2. **Logic that maps to JavaScript** — conditionals, ternaries, loops, string concatenation

The `ErbExtractor` filter walks the Ruby AST and:
- Assigns each server-only expression a key (`v0`, `v1`, `v2`, ...)
- Records the Ruby source string for later server-side evaluation
- Replaces the AST node with a local variable reference

The result is a JavaScript function that operates on a flat data object:

```javascript
// Compiled from: <%= tag.span @message.sender.name, class: [...] %>
function _escape(s) { /* HTML entity escaping */ }
function _tag(name, content, attrs) { /* builds HTML tag string */ }

let { v0, v1, v2, v3, ... } = data;
// v0 = server-evaluated "@message.sender.name"
// v1 = server-evaluated "@message.read?"
// ...
__buf += _tag("span", _escape(String(v0)), {
  "class": ["text-sm text-gray-900 truncate", v1 ? "font-medium" : "font-bold"]
});
```

### Server-Side Data Building

`build_data(record)` uses `DataEvaluator` to evaluate all extracted Ruby expressions:

```ruby
# DataEvaluator sets up context matching the component:
# - Binds @message = record
# - Includes ActionView helpers (DateHelper, TextHelper, etc.)
# - Delegates unknown methods to a component instance (for private helpers)

# For each expression key:
# v0 → instance_eval("@message.sender.name")  → "Alice"
# v1 → instance_eval("@message.read?")        → true
# v2 → instance_eval("time_ago_in_words(@message.created_at)") → "3 hours"
```

The result is a flat hash like `{ "v0" => "Alice", "v1" => true, "dom_id" => "message_42", "id" => 42 }`.

### Collections

For `.each` loops, the extractor handles per-item expressions:

```erb
<% @message.labels.each do |label| %>
  <%= tag.span label.name, class: [label_color_classes(label)] %>
<% end %>
```

The collection (`@message.labels`) is extracted as a server variable. Expressions inside the loop that reference the block variable (`label.name`, `label_color_classes(label)`) become **collection computed fields** — lambdas evaluated per-item server-side. The JS iterates over an array of pre-computed per-item hashes.

### Nested Components

Non-live components rendered inside a live component (e.g., `render LabelBadgeComponent.new(label: label)`) can be inlined: the child's ERB is also compiled to JS and embedded as a helper function (`_render__nc0(data)`) inside the parent template.

Live components rendered inside another live component are excluded from inlining — they get their own independent wrapper and ActionCable subscription.

### Raw HTML

Expressions wrapped in `raw(...)` bypass HTML escaping in the compiled JS. The extractor marks these fields so the compiler skips the `_escape()` wrapper.

## Communication Layer

### ActionCable Channel

`LiveComponentChannel` authenticates subscriptions using Turbo's signed stream names. Payloads are `{ action: "update"|"destroy", data: {...} }`.

Optional gzip compression is available (`LiveComponentChannel.compress = true`) — payloads are gzip-compressed and base64-encoded as `{ z: "..." }`.

### Shared Subscriptions

Multiple component instances on the same stream share a single WebSocket subscription. Each Stimulus controller registers as a handler; when a message arrives, each handler checks if `data.dom_id` matches its element's ID before rendering.

### Action Dispatch

Actions go through HTTP (not WebSocket):

```
Client click
    │
    ▼  POST /live_component_actions
    │  { token: <signed>, action_name: "toggle_star", params: {...} }
    │
    ▼  Server verifies token → { c: "MessageRowComponent", m: "Message", r: 42 }
    │  Calls component_class.execute_action(:toggle_star, record)
    │  Action mutates the model
    │
    ▼  Model after_update_commit fires
    │  Broadcasts JSON data to all subscribed clients
    │
    ▼  All clients re-render
```

## Security

- **Stream authentication**: Uses Turbo's signed stream names — the server signs stream identifiers and the client sends the signed token for verification
- **Action tokens**: Signed with `Rails.application.message_verifier(:live_component_action)` containing `{ class, model, record_id }` — prevents arbitrary class/method invocation
- **HTML escaping**: All interpolated values in compiled JS are wrapped in `_escape()` unless explicitly marked as raw

## Key Files

| File | Role |
|---|---|
| `app/components/concerns/live_component.rb` | The concern — DSL, `render_in` override, `build_data`, `execute_action` |
| `lib/live_component/compiler.rb` | ERB-to-JS compilation orchestration |
| `lib/live_component/erb_extractor.rb` | Ruby2JS filter that extracts server-only expressions |
| `lib/live_component/data_evaluator.rb` | Evaluates extracted Ruby expressions against live data |
| `lib/live_component/wrapper.rb` | Produces the wrapper `<div>` with data attributes |
| `app/channels/live_component_channel.rb` | ActionCable channel for broadcasting updates |
| `app/models/concerns/broadcastable.rb` | AR concern hooking lifecycle callbacks to broadcasts |
| `app/controllers/live_component_actions_controller.rb` | HTTP endpoint for client-triggered actions |
| `app/javascript/controllers/live_renderer_controller.js` | Stimulus controller — template compilation, subscriptions, rendering |

## Design Tradeoffs

**Why not Turbo Streams for updates?** Turbo Streams require the server to re-render full HTML on every update. This system sends ~200 bytes of JSON data and re-renders client-side. Less bandwidth, no server-side HTML serialization per update.

**Why compile ERB to JS instead of handwriting JS templates?** One template serves both server and client rendering. No duplication, no drift.

**What can't be compiled?** Complex Ruby-only constructs like `form_with`, ActiveStorage helpers, or deeply nested partials. These should be placed outside the live-renderer wrapper (as done with the inline reply form).
