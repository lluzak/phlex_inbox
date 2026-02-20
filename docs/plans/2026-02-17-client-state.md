# Client State for Live Components — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow live components to declare client-side state fields that survive server-triggered re-renders and can be updated purely from JavaScript.

**Architecture:** Add a `client_state` DSL to `LiveComponent`. The wrapper embeds initial state and initial server data as JSON data attributes. The Stimulus controller stores client state in memory, merges it with server data on every render, and exposes a `setState` action for client-side updates.

**Tech Stack:** Ruby (ActiveSupport concern), JavaScript (Stimulus controller), existing LiveComponent infrastructure.

---

### Task 1: Add `client_state` DSL to `LiveComponent` concern

**Files:**
- Modify: `app/components/concerns/live_component.rb`
- Test: `test/components/live_component_test.rb`

**Step 1: Write the failing test**

Add to `test/components/live_component_test.rb`:

```ruby
# --- client_state ---

test "client_state registers fields with defaults" do
  assert_equal({ selected: { default: false } }, MessageRowComponent._client_state_fields)
end

test "component without client_state has empty client_state_fields" do
  assert_equal({}, MessageLabelsComponent._client_state_fields)
end

test "client_state_values returns defaults when no kwargs override" do
  values = MessageRowComponent.client_state_values
  assert_equal({ "selected" => false }, values)
end

test "client_state_values returns overridden values from kwargs" do
  values = MessageRowComponent.client_state_values(selected: true)
  assert_equal({ "selected" => true }, values)
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/live_component_test.rb -n /client_state/ -v`
Expected: FAIL — `_client_state_fields` undefined

**Step 3: Write minimal implementation**

In `app/components/concerns/live_component.rb`, add to the `included` block:

```ruby
class_attribute :_client_state_fields, instance_writer: false, default: {}
```

Add to `class_methods`:

```ruby
def client_state(name, default: nil)
  self._client_state_fields = _client_state_fields.merge(
    name.to_sym => { default: default }
  )
end

def client_state_values(**kwargs)
  _client_state_fields.each_with_object({}) do |(name, config), hash|
    hash[name.to_s] = kwargs.key?(name) ? kwargs[name] : config[:default]
  end
end
```

**Step 4: Add `client_state :selected` to MessageRowComponent**

In `app/components/message_row_component.rb`, add after `live_action :toggle_star`:

```ruby
client_state :selected, default: false
```

**Step 5: Run test to verify it passes**

Run: `bin/rails test test/components/live_component_test.rb -n /client_state/ -v`
Expected: PASS

**Step 6: Commit**

```bash
git add app/components/concerns/live_component.rb app/components/message_row_component.rb test/components/live_component_test.rb
git commit -m "feat: add client_state DSL to LiveComponent"
```

---

### Task 2: Embed client state and initial server data in wrapper

**Files:**
- Modify: `lib/live_component/wrapper.rb`
- Modify: `app/components/concerns/live_component.rb` (render_in)
- Test: `test/components/live_component_test.rb`

**Step 1: Write the failing test**

Add to `test/components/live_component_test.rb`:

```ruby
# --- wrapper: client state & initial data ---

test "render_in embeds client state as data attribute" do
  component = MessageRowComponent.new(message: @message, selected: true)
  html = component.render_in(ApplicationController.new.view_context)

  assert_match(/data-live-renderer-state-value/, html)
  # Should contain the initial client state JSON
  state_match = html.match(/data-live-renderer-state-value="([^"]*)"/)
  assert_not_nil state_match
  state = JSON.parse(CGI.unescapeHTML(state_match[1]))
  assert_equal true, state["selected"]
end

test "render_in embeds initial server data as data attribute" do
  component = MessageRowComponent.new(message: @message, selected: false)
  html = component.render_in(ApplicationController.new.view_context)

  assert_match(/data-live-renderer-data-value/, html)
  data_match = html.match(/data-live-renderer-data-value="([^"]*)"/)
  assert_not_nil data_match
  data = JSON.parse(CGI.unescapeHTML(data_match[1]))
  assert_equal "message_#{@message.id}", data["dom_id"]
end

test "render_in for component without client_state omits state attribute" do
  component = MessageLabelsComponent.new(message: @message)
  html = component.render_in(ApplicationController.new.view_context)

  assert_no_match(/data-live-renderer-state-value/, html)
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/live_component_test.rb -n /render_in/ -v`
Expected: FAIL — no state data attribute in output

**Step 3: Update `render_in` to pass client state kwargs**

In `app/components/concerns/live_component.rb`, update `render_in`:

```ruby
def render_in(view_context, &block)
  inner_html = super
  return inner_html unless self.class._live_model_attr

  record = instance_variable_get(:"@#{self.class.live_model_attr}")
  return inner_html unless record

  stream = LiveComponent::Wrapper.find_stream_for(self.class, record)

  client_state = if self.class._client_state_fields.any?
    kwargs = {}
    self.class._client_state_fields.each_key do |name|
      kwargs[name] = instance_variable_get(:"@#{name}")
    end
    self.class.client_state_values(**kwargs)
  end

  LiveComponent::Wrapper.wrap(self.class, record, inner_html, stream: stream, client_state: client_state)
end
```

**Step 4: Update `Wrapper.wrap` to accept and embed client state and initial data**

In `lib/live_component/wrapper.rb`:

```ruby
def wrap(component_class, record, inner_html, stream: nil, client_state: nil)
  dom_id_val = component_class.dom_id_for(record)

  attrs = [
    %(id="#{dom_id_val}"),
    %(data-controller="live-renderer"),
    %(data-live-renderer-template-value="#{component_class.encoded_template}")
  ]

  if stream
    signed = Turbo::StreamsChannel.signed_stream_name(stream)
    attrs << %(data-live-renderer-stream-value="#{signed}")
  end

  if component_class._live_actions.any?
    attrs << %(data-live-renderer-action-url-value="#{Rails.application.routes.url_helpers.live_component_actions_path}")
    attrs << %(data-live-renderer-action-token-value="#{component_class.live_action_token(record)}")
  end

  if client_state
    attrs << %(data-live-renderer-state-value="#{ERB::Util.html_escape(client_state.to_json)}")
    initial_data = component_class.build_data(record, **client_state.symbolize_keys)
    attrs << %(data-live-renderer-data-value="#{ERB::Util.html_escape(initial_data.to_json)}")
  end

  %(<div #{attrs.join(" ")}>#{inner_html}</div>).html_safe
end
```

**Step 5: Run test to verify it passes**

Run: `bin/rails test test/components/live_component_test.rb -n /render_in/ -v`
Expected: PASS

**Step 6: Run full test suite to check for regressions**

Run: `bin/rails test -v`
Expected: All passing

**Step 7: Commit**

```bash
git add lib/live_component/wrapper.rb app/components/concerns/live_component.rb test/components/live_component_test.rb
git commit -m "feat: embed client state and initial data in wrapper"
```

---

### Task 3: Update Stimulus controller to manage client state

**Files:**
- Modify: `app/javascript/controllers/live_renderer_controller.js`

**Step 1: Add `state` and `data` to Stimulus values**

In the `static values` declaration, add:

```javascript
static values = {
  template: String,
  templateId: String,
  stream: String,
  actionUrl: String,
  actionToken: String,
  state: { type: Object, default: {} },
  data: { type: Object, default: {} }
}
```

**Step 2: Initialize client state and last server data on connect**

Update `connect()`:

```javascript
connect() {
  log("connect", this.element.id)

  this.clientState = { ...this.stateValue }
  this.lastServerData = Object.keys(this.dataValue).length > 0 ? this.dataValue : null

  const encoded = this.resolveTemplate()
  this.renderFn = encoded ? compileTemplate(encoded) : null

  if (!this.renderFn) {
    if (this.hasTemplateValue || this.hasTemplateIdValue) {
      log("ERROR no render function, skipping")
    }
    if (!this.streamValue) return
  }
  log("template compiled")

  if (!this.streamValue) {
    log("no stream value, skipping subscription")
    return
  }

  subscribe(this.streamValue, this)
}
```

**Step 3: Merge client state on server update**

Update `handleMessage()`:

```javascript
handleMessage(message) {
  const { action, data } = message

  if (action === "update" && data.dom_id === this.element.id) {
    this.lastServerData = data
    if (this.renderFn) this.render({ ...data, ...this.clientState })
  } else if (action === "destroy" && data.dom_id === this.element.id) {
    log("removing element", this.element.id)
    this.element.remove()
  }
}
```

**Step 4: Add `setState` action**

Add new method to the controller:

```javascript
setState(event) {
  event.preventDefault()
  event.stopPropagation()

  const updates = { ...event.params }
  delete updates.action
  Object.assign(this.clientState, updates)

  if (this.lastServerData && this.renderFn) {
    this.render({ ...this.lastServerData, ...this.clientState })
  }
}
```

**Step 5: Update `render` method to not take data arg directly from handleMessage**

The `render` method already takes a `data` arg and calls `this.renderFn(data)`, so it works as-is — we just pass merged data from the callers above.

**Step 6: Manual test**

1. Start the dev server: `bin/dev`
2. Open the inbox, click a message row — the detail loads in the right pane
3. In a Rails console, update a message: `Message.first.update(subject: "Changed")`
4. Verify the message row re-renders with the new subject
5. If the row was selected (bg-blue-50), verify the selection highlight is preserved after re-render

**Step 7: Commit**

```bash
git add app/javascript/controllers/live_renderer_controller.js
git commit -m "feat: Stimulus controller manages client state across re-renders"
```

---

### Task 4: Update message list to pass client state through manual wrapper

**Files:**
- Modify: `app/components/message_list_component.html.erb`
- Modify: `app/components/message_list_component.rb`

**Step 1: Add helper to build initial state and data per row**

In `app/components/message_list_component.rb`, add private methods:

```ruby
def client_state_for(message)
  MessageRowComponent.client_state_values(selected: message.id == @selected_id).to_json
end

def initial_data_for(message)
  MessageRowComponent.build_data(message, selected: message.id == @selected_id).to_json
end
```

**Step 2: Add data attributes to the manual wrapper div**

In `app/components/message_list_component.html.erb`, update the wrapper div (lines 13-18) to include state and data attributes:

```erb
<div id="<%= dom_id(message) %>"
     data-controller="live-renderer"
     data-live-renderer-template-id-value="<%= MessageRowComponent.template_element_id %>"
     <% if signed_stream_name %>data-live-renderer-stream-value="<%= signed_stream_name %>"<% end %>
     data-live-renderer-action-url-value="<%= live_component_actions_path %>"
     data-live-renderer-action-token-value="<%= MessageRowComponent.live_action_token(message) %>"
     data-live-renderer-state-value="<%= client_state_for(message) %>"
     data-live-renderer-data-value="<%= initial_data_for(message) %>">
```

**Step 3: Manual test**

1. Start the dev server: `bin/dev`
2. Verify message list renders correctly with the new attributes
3. Inspect a row in dev tools — confirm `data-live-renderer-state-value` and `data-live-renderer-data-value` are present

**Step 4: Commit**

```bash
git add app/components/message_list_component.rb app/components/message_list_component.html.erb
git commit -m "feat: pass client state through message list manual wrapper"
```

---

### Task 5: Add selection toggle via setState

**Files:**
- Modify: `app/components/message_row_component.html.erb`

**Step 1: Add setState action to the row's link**

In `app/components/message_row_component.html.erb`, update the `<a>` tag (line 1) to include a setState trigger:

```erb
<a href="<%= message_path(@message) %>"
   class="block border-b border-gray-100 hover:bg-gray-50 transition-colors <%= @selected ? 'bg-blue-50' : 'bg-white' %>"
   data-turbo-frame="message_detail"
   data-turbo-action="advance"
   data-action="click->live-renderer#setState"
   data-live-renderer-selected-param="true">
```

Note: this only sets `selected: true` on the clicked row. Deselecting the previously selected row would be handled by a parent controller or additional logic — out of scope for this initial implementation.

**Step 2: Manual test**

1. Click a message row
2. Trigger a server update on that message
3. Verify the blue selection background persists after re-render

**Step 3: Commit**

```bash
git add app/components/message_row_component.html.erb
git commit -m "feat: wire setState action for row selection"
```

---

### Task 6: Update documentation

**Files:**
- Modify: `docs/live_components.md`

**Step 1: Add Client State section to the docs**

Add a new section after "Actions" covering:
- The `client_state` DSL
- How state is embedded, stored, and merged
- The `setState` Stimulus action
- Example usage

**Step 2: Commit**

```bash
git add docs/live_components.md
git commit -m "docs: add client state section to live components docs"
```
