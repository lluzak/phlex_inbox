# Notify+Pull Subscription Strategy Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a "notify" subscription strategy to the live component system where the backend notifies clients of changes, and clients request updates with their state params (filters), so the server can evaluate per-client whether a record still matches.

**Architecture:** The existing push strategy stays as default. A new `strategy=notify` on the subscriber side makes the live-renderer ignore broadcast data and instead send a `request_update` message back over ActionCable with its params. The server's `LiveComponentChannel#request_update` evaluates the filters, responds with `update` (data) or `remove` per client via `transmit`. This replaces the client-side `filtered-list` controller.

**Tech Stack:** ActionCable, Stimulus, Rails scopes

---

### Task 1: Add `request_update` to LiveComponentChannel

**Files:**
- Modify: `app/channels/live_component_channel.rb`
- Create: `test/channels/live_component_channel_test.rb`

**Step 1: Write the failing test**

Create `test/channels/live_component_channel_test.rb`:

```ruby
require "test_helper"

class LiveComponentChannelTest < ActionCable::Channel::TestCase
  setup do
    @sender = Contact.create!(name: "Alice", email: "alice@example.com")
    @recipient = Contact.create!(name: "Bob", email: "bob@example.com")
    @message = Message.create!(subject: "Hi", body: "Hello", sender: @sender, recipient: @recipient, label: "inbox")
  end

  test "request_update transmits update when message matches filters" do
    stub_connection

    subscribe(signed_stream_name: stream_name_for(@recipient))

    perform :request_update, {
      component: "MessageRowComponent",
      record_id: @message.id,
      dom_id: "message_#{@message.id}",
      params: {}
    }

    assert_equal "update", transmissions.last["action"]
    assert_equal "message_#{@message.id}", transmissions.last["data"]["dom_id"]
  end

  test "request_update transmits remove when message does not match unread filter" do
    @message.update!(read_at: Time.current)

    stub_connection

    subscribe(signed_stream_name: stream_name_for(@recipient))

    perform :request_update, {
      component: "MessageRowComponent",
      record_id: @message.id,
      dom_id: "message_#{@message.id}",
      params: { "unread" => "1" }
    }

    assert_equal "remove", transmissions.last["action"]
    assert_equal "message_#{@message.id}", transmissions.last["dom_id"]
  end

  test "request_update transmits remove when message does not match starred filter" do
    stub_connection

    subscribe(signed_stream_name: stream_name_for(@recipient))

    perform :request_update, {
      component: "MessageRowComponent",
      record_id: @message.id,
      dom_id: "message_#{@message.id}",
      params: { "starred" => "1" }
    }

    assert_equal "remove", transmissions.last["action"]
  end

  test "request_update transmits remove when message does not match label filter" do
    label = Label.create!(name: "work", color: "blue")

    stub_connection

    subscribe(signed_stream_name: stream_name_for(@recipient))

    perform :request_update, {
      component: "MessageRowComponent",
      record_id: @message.id,
      dom_id: "message_#{@message.id}",
      params: { "label_ids" => [label.id] }
    }

    assert_equal "remove", transmissions.last["action"]
  end

  test "request_update transmits update when message matches label filter" do
    label = Label.create!(name: "work", color: "blue")
    @message.labels << label

    stub_connection

    subscribe(signed_stream_name: stream_name_for(@recipient))

    perform :request_update, {
      component: "MessageRowComponent",
      record_id: @message.id,
      dom_id: "message_#{@message.id}",
      params: { "label_ids" => [label.id] }
    }

    assert_equal "update", transmissions.last["action"]
  end

  test "request_update does nothing for nonexistent record" do
    stub_connection

    subscribe(signed_stream_name: stream_name_for(@recipient))

    perform :request_update, {
      component: "MessageRowComponent",
      record_id: 999999,
      dom_id: "message_999999",
      params: {}
    }

    assert_empty transmissions
  end

  private

  def stream_name_for(contact)
    Turbo::StreamsChannel.signed_stream_name([contact, :messages])
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bin/rails test test/channels/live_component_channel_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'request_update'`

**Step 3: Write minimal implementation**

Replace `app/channels/live_component_channel.rb`:

```ruby
# frozen_string_literal: true

class LiveComponentChannel < ApplicationCable::Channel
  mattr_accessor :compress, default: false

  def subscribed
    stream_name = verified_stream_name
    if stream_name
      stream_from stream_name
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  def request_update(data)
    component_class = data["component"].constantize
    model_attr = component_class.live_model_attr
    model_class = model_attr.to_s.classify.constantize
    record = model_class.find_by(id: data["record_id"])
    return unless record

    filter_params = data["params"] || {}

    if matches_filters?(record, filter_params)
      transmit({ "action" => "update", "data" => component_class.build_data(record) })
    else
      transmit({ "action" => "remove", "dom_id" => data["dom_id"] })
    end
  end

  private

  def verified_stream_name
    Turbo::StreamsChannel.verified_stream_name(params[:signed_stream_name])
  rescue
    nil
  end

  def matches_filters?(record, params)
    scope = record.class.where(id: record.id)
    scope = scope.unread if params["unread"] == "1"
    scope = scope.starred_messages if params["starred"] == "1"
    label_ids = Array(params["label_ids"]).map(&:to_i).select(&:positive?)
    scope = scope.filter_by_labels(label_ids) if label_ids.any?
    scope.exists?
  end

  class << self
    def broadcast_data(streamables, action:, data:)
      signed = Turbo::StreamsChannel.signed_stream_name(streamables)
      stream_name = Turbo::StreamsChannel.verified_stream_name(signed)

      payload = { action: action, data: data }

      if compress
        json = ActiveSupport::JSON.encode(payload)
        ActionCable.server.broadcast(stream_name, { z: Base64.strict_encode64(ActiveSupport::Gzip.compress(json)) })
      else
        ActionCable.server.broadcast(stream_name, payload)
      end
    end
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bin/rails test test/channels/live_component_channel_test.rb`
Expected: All PASS

**Step 5: Commit**

```bash
git add app/channels/live_component_channel.rb test/channels/live_component_channel_test.rb
git commit -m "feat: add request_update to LiveComponentChannel for notify+pull"
```

---

### Task 2: Add strategy and params values to live-renderer controller

**Files:**
- Modify: `app/javascript/controllers/live_renderer_controller.js`

**Step 1: Add new Stimulus values**

In the `static values` block, add:

```javascript
static values = {
  template: String,
  templateId: String,
  stream: String,
  actionUrl: String,
  actionToken: String,
  state: { type: Object, default: {} },
  data: { type: Object, default: {} },
  strategy: { type: String, default: "push" },
  component: { type: String, default: "" },
  params: { type: Object, default: {} }
}
```

**Step 2: Update handleMessage to branch on strategy**

Replace the `handleMessage` method:

```javascript
handleMessage(message) {
  const { action, data } = message

  if (action === "update" && data.dom_id === this.element.id) {
    if (this.strategyValue === "notify") {
      this.requestUpdate(data)
      return
    }
    this.lastServerData = data
    if (this.renderFn) this.render({ ...data, ...this.clientState })
    this.element.dispatchEvent(new CustomEvent("live-renderer:updated", {
      bubbles: true,
      detail: { data }
    }))
  } else if (action === "remove" && data.dom_id === this.element.id) {
    this.element.remove()
  } else if (action === "destroy" && data.dom_id === this.element.id) {
    log("removing element", this.element.id)
    this.element.remove()
  }
}
```

**Step 3: Add requestUpdate method**

Add after `handleMessage`:

```javascript
requestUpdate(data) {
  const sub = findSubscription(this.streamValue)
  if (!sub) return

  sub.perform("request_update", {
    dom_id: this.element.id,
    component: this.componentValue,
    record_id: data.id,
    params: this.paramsValue
  })
}
```

**Step 4: Handle the response**

The response from `request_update` comes back through the same `received` callback, which calls `handleMessage`. For `action: "update"`, the notify controller would loop — receiving its own response would trigger another `requestUpdate`.

To prevent this, the notify handler should process the response when it comes from a `request_update` response. The simplest fix: after calling `requestUpdate`, set a flag. When the next `update` arrives for this element, process it normally (push-style) and clear the flag.

Update `requestUpdate`:

```javascript
requestUpdate(data) {
  const sub = findSubscription(this.streamValue)
  if (!sub) return

  this._awaitingResponse = true
  sub.perform("request_update", {
    dom_id: this.element.id,
    component: this.componentValue,
    record_id: data.id,
    params: this.paramsValue
  })
}
```

Update the `handleMessage` notify branch:

```javascript
if (action === "update" && data.dom_id === this.element.id) {
  if (this.strategyValue === "notify" && !this._awaitingResponse) {
    this.requestUpdate(data)
    return
  }
  this._awaitingResponse = false
  this.lastServerData = data
  if (this.renderFn) this.render({ ...data, ...this.clientState })
  this.element.dispatchEvent(new CustomEvent("live-renderer:updated", {
    bubbles: true,
    detail: { data }
  }))
}
```

**Step 5: Verify existing tests still pass**

Run: `bin/rails test`
Expected: All PASS

**Step 6: Commit**

```bash
git add app/javascript/controllers/live_renderer_controller.js
git commit -m "feat: add notify strategy to live-renderer controller"
```

---

### Task 3: Wire notify strategy into MessageListComponent

**Files:**
- Modify: `app/components/message_list_component.html.erb`
- Modify: `app/components/message_list_component.rb`

**Step 1: Update the template**

In `message_list_component.html.erb`, update the message row wrapper div to include strategy, component, and params attributes. Replace the `<% @messages.each do |message| %>` block:

```erb
<% strategy = @active_filters.any? ? "notify" : "push" %>
<% @messages.each do |message| %>
  <div id="<%= dom_id(message) %>"
       class="<%= message.id == @selected_id ? 'bg-blue-50' : 'bg-white' %>"
       data-list-toggle-target="item"
       data-controller="live-renderer"
       data-live-renderer-template-id-value="<%= MessageRowComponent.template_element_id %>"
       <% if signed_stream_name %>data-live-renderer-stream-value="<%= signed_stream_name %>"<% end %>
       data-live-renderer-action-url-value="<%= live_component_actions_path %>"
       data-live-renderer-action-token-value="<%= MessageRowComponent.live_action_token(message) %>"
       data-live-renderer-state-value="<%= client_state_for(message) %>"
       data-live-renderer-data-value="<%= initial_data_for(message) %>"
       data-live-renderer-strategy-value="<%= strategy %>"
       data-live-renderer-component-value="MessageRowComponent"
       data-live-renderer-params-value="<%= @active_filters.to_json %>">
    <%= render MessageRowComponent.new(message: message, selected: message.id == @selected_id) %>
  </div>
<% end %>
```

**Step 2: Remove filtered-list controller from the template**

In the `message_items` div, remove `filtered-list` controller and its data attributes. Change:

```erb
<div id="message_items" data-controller="list-toggle filtered-list" data-list-toggle-active-class="bg-blue-50" data-list-toggle-inactive-class="bg-white" data-filtered-list-label-ids-value="<%= active_label_ids_json %>" data-filtered-list-unread-value="<%= @active_filters['unread'] == '1' %>" data-filtered-list-starred-value="<%= @active_filters['starred'] == '1' %>" >
```

To:

```erb
<div id="message_items" data-controller="list-toggle" data-list-toggle-active-class="bg-blue-50" data-list-toggle-inactive-class="bg-white">
```

**Step 3: Remove `active_label_ids_json` from MessageListComponent**

In `app/components/message_list_component.rb`, remove the `active_label_ids_json` method (no longer needed).

**Step 4: Delete the filtered-list controller**

Delete `app/javascript/controllers/filtered_list_controller.js`.

**Step 5: Remove custom `build_data` override from MessageRowComponent**

In `app/components/message_row_component.rb`, remove the `build_data` override that added `label_ids`, `starred`, and `read` fields. These were only needed for client-side filtering which is now server-side. Delete:

```ruby
def self.build_data(record, **kwargs)
  data = super
  data["label_ids"] = record.label_ids
  data["starred"] = record.starred?
  data["read"] = record.read?
  data
end
```

**Step 6: Run the full test suite**

Run: `bin/rails test`
Expected: All PASS

**Step 7: Commit**

```bash
git add app/components/message_list_component.html.erb app/components/message_list_component.rb app/components/message_row_component.rb
git rm app/javascript/controllers/filtered_list_controller.js
git commit -m "feat: wire notify strategy into message list, remove client-side filtering"
```

---

### Task 4: Smoke test

**Steps:**
1. Start the dev server: `bin/dev`
2. Open inbox, click "Unread" filter — only unread messages shown
3. Open an unread message in the list (detail panel marks it as read)
4. Verify the message is removed from the filtered list via ActionCable notify+pull
5. Click "Starred" filter — only starred messages shown
6. Unstar a message via the star button — verify it's removed from the list
7. Filter by a label — remove that label from a message in detail view — verify removal
8. No filters active — verify messages update normally (push behavior)
9. Switch folders — verify filters reset
