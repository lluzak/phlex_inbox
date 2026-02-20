# Message List Filtering Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Gmail-style filter chips (Unread, Starred, per-label) to the message list, powered by server-side query param filtering via Turbo Frames.

**Architecture:** Filter chips render as `<a>` tags inside `MessageListComponent`, each linking to the current folder path with toggled query params and targeting `#message_list` Turbo Frame. A shared `apply_filters` concern in the controller chains existing scopes based on params. Folder navigation resets all filters.

**Tech Stack:** Rails scopes, ViewComponent, Turbo Frames, Tailwind CSS

---

### Task 1: Add `filter_by_label` scope to Message model

**Files:**
- Modify: `app/models/message.rb:27` (add scope after `starred_messages`)
- Test: `test/models/message_test.rb`

**Step 1: Write the failing test**

Add to `test/models/message_test.rb`:

```ruby
test "filter_by_label scope filters by label_id" do
  msg = Message.create!(subject: "Hi", body: "Hello", sender: @sender, recipient: @recipient)
  label = Label.create!(name: "work", color: "blue")
  msg.labels << label

  unlabeled = Message.create!(subject: "Other", body: "World", sender: @sender, recipient: @recipient)

  assert_includes Message.filter_by_label(label.id), msg
  assert_not_includes Message.filter_by_label(label.id), unlabeled
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/message_test.rb -n test_filter_by_label_scope_filters_by_label_id`
Expected: FAIL — `NoMethodError: undefined method 'filter_by_label'`

**Step 3: Write minimal implementation**

In `app/models/message.rb`, after line 28 (`scope :starred_messages`), add:

```ruby
scope :filter_by_label, ->(label_id) { joins(:labelings).where(labelings: { label_id: label_id }) }
```

**Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/message_test.rb -n test_filter_by_label_scope_filters_by_label_id`
Expected: PASS

**Step 5: Commit**

```bash
git add app/models/message.rb test/models/message_test.rb
git commit -m "feat: add filter_by_label scope to Message"
```

---

### Task 2: Add `apply_filters` to MessagesController

**Files:**
- Modify: `app/controllers/messages_controller.rb`
- Test: `test/controllers/messages_controller_test.rb` (create)

**Step 1: Write the failing test**

Create `test/controllers/messages_controller_test.rb`:

```ruby
require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sender = Contact.create!(name: "Alice", email: "alice@example.com")
    @recipient = Contact.create!(name: "Bob", email: "bob@example.com")
    # Stub current_contact to return @recipient
    ApplicationController.any_instance.stubs(:current_contact).returns(@recipient)
  end

  test "index returns all inbox messages without filters" do
    msg = Message.create!(subject: "Hi", body: "Hello", sender: @sender, recipient: @recipient, label: "inbox")
    get root_path
    assert_response :success
  end

  test "index with unread=1 returns only unread messages" do
    read_msg = Message.create!(subject: "Read", body: "Body", sender: @sender, recipient: @recipient, label: "inbox", read_at: Time.current)
    unread_msg = Message.create!(subject: "Unread", body: "Body", sender: @sender, recipient: @recipient, label: "inbox")

    get root_path(unread: "1")
    assert_response :success
    assert_select "[id='#{ActionView::RecordIdentifier.dom_id(unread_msg)}']"
    assert_select "[id='#{ActionView::RecordIdentifier.dom_id(read_msg)}']", count: 0
  end

  test "index with starred=1 returns only starred messages" do
    starred_msg = Message.create!(subject: "Star", body: "Body", sender: @sender, recipient: @recipient, label: "inbox", starred: true)
    normal_msg = Message.create!(subject: "Normal", body: "Body", sender: @sender, recipient: @recipient, label: "inbox")

    get root_path(starred: "1")
    assert_response :success
    assert_select "[id='#{ActionView::RecordIdentifier.dom_id(starred_msg)}']"
    assert_select "[id='#{ActionView::RecordIdentifier.dom_id(normal_msg)}']", count: 0
  end

  test "index with label_id filters by label" do
    label = Label.create!(name: "work", color: "blue")
    labeled_msg = Message.create!(subject: "Work", body: "Body", sender: @sender, recipient: @recipient, label: "inbox")
    labeled_msg.labels << label
    unlabeled_msg = Message.create!(subject: "Other", body: "Body", sender: @sender, recipient: @recipient, label: "inbox")

    get root_path(label_id: label.id)
    assert_response :success
    assert_select "[id='#{ActionView::RecordIdentifier.dom_id(labeled_msg)}']"
    assert_select "[id='#{ActionView::RecordIdentifier.dom_id(unlabeled_msg)}']", count: 0
  end

  test "sent with unread=1 applies filter" do
    unread_sent = Message.create!(subject: "Sent", body: "Body", sender: @recipient, recipient: @sender, label: "sent", read_at: nil)
    read_sent = Message.create!(subject: "SentRead", body: "Body", sender: @recipient, recipient: @sender, label: "sent", read_at: Time.current)

    get sent_messages_path(unread: "1")
    assert_response :success
    assert_select "[id='#{ActionView::RecordIdentifier.dom_id(unread_sent)}']"
    assert_select "[id='#{ActionView::RecordIdentifier.dom_id(read_sent)}']", count: 0
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/messages_controller_test.rb`
Expected: Failures on filter tests (messages not being filtered)

**Step 3: Write minimal implementation**

In `app/controllers/messages_controller.rb`, add `apply_filters` and call it in each action:

```ruby
class MessagesController < ApplicationController
  before_action :set_message, only: [:show, :toggle_star, :toggle_read, :move]

  def index
    @folder = "inbox"
    @messages = current_contact.received_messages.inbox.includes(:labels).newest_first
    apply_filters
    render_message_list_or_full
  end

  def sent
    @folder = "sent"
    @messages = current_contact.sent_messages.sent_box.includes(:labels).newest_first
    apply_filters
    render_message_list_or_full
  end

  def archive
    @folder = "archive"
    @messages = current_contact.received_messages.archived.includes(:labels).newest_first
    apply_filters
    render_message_list_or_full
  end

  def trash
    @folder = "trash"
    @messages = current_contact.received_messages.trashed.includes(:labels).newest_first
    apply_filters
    render_message_list_or_full
  end

  # ... show, create, search, toggle_star, toggle_read, move unchanged ...

  private

  # ... existing private methods ...

  def apply_filters
    @messages = @messages.unread if params[:unread] == "1"
    @messages = @messages.starred_messages if params[:starred] == "1"
    @messages = @messages.filter_by_label(params[:label_id]) if params[:label_id].present?
    @active_filters = params.slice(:unread, :starred, :label_id).permit(:unread, :starred, :label_id).to_h
  end
end
```

**Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/messages_controller_test.rb`
Expected: All PASS

**Step 5: Commit**

```bash
git add app/controllers/messages_controller.rb test/controllers/messages_controller_test.rb
git commit -m "feat: add server-side message filtering via query params"
```

---

### Task 3: Create FilterChipsComponent

**Files:**
- Create: `app/components/filter_chips_component.rb`
- Create: `app/components/filter_chips_component.html.erb`
- Test: `test/components/filter_chips_component_test.rb`

**Step 1: Write the failing test**

Create `test/components/filter_chips_component_test.rb`:

```ruby
require "test_helper"

class FilterChipsComponentTest < ViewComponent::TestCase
  setup do
    @label = Label.create!(name: "work", color: "blue")
  end

  test "renders unread and starred chips" do
    component = FilterChipsComponent.new(
      current_path: "/",
      active_filters: {},
      labels: [@label]
    )
    render_inline(component)

    assert_selector "a", text: "Unread"
    assert_selector "a", text: "Starred"
  end

  test "renders label chips" do
    component = FilterChipsComponent.new(
      current_path: "/",
      active_filters: {},
      labels: [@label]
    )
    render_inline(component)

    assert_selector "a", text: "work"
  end

  test "active unread chip links to path without unread param" do
    component = FilterChipsComponent.new(
      current_path: "/",
      active_filters: { "unread" => "1" },
      labels: []
    )
    render_inline(component)

    unread_link = page.find("a", text: "Unread")
    assert_equal "/", unread_link[:href]
  end

  test "inactive unread chip links to path with unread param" do
    component = FilterChipsComponent.new(
      current_path: "/",
      active_filters: {},
      labels: []
    )
    render_inline(component)

    unread_link = page.find("a", text: "Unread")
    assert_equal "/?unread=1", unread_link[:href]
  end

  test "active chip has filled style" do
    component = FilterChipsComponent.new(
      current_path: "/",
      active_filters: { "unread" => "1" },
      labels: []
    )
    render_inline(component)

    unread_link = page.find("a", text: "Unread")
    assert_includes unread_link[:class], "bg-blue-600"
  end

  test "inactive chip has outline style" do
    component = FilterChipsComponent.new(
      current_path: "/",
      active_filters: {},
      labels: []
    )
    render_inline(component)

    unread_link = page.find("a", text: "Unread")
    assert_includes unread_link[:class], "border-gray-300"
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/filter_chips_component_test.rb`
Expected: FAIL — `NameError: uninitialized constant FilterChipsComponent`

**Step 3: Write minimal implementation**

Create `app/components/filter_chips_component.rb`:

```ruby
# frozen_string_literal: true

class FilterChipsComponent < ApplicationComponent
  STATUS_FILTERS = [
    { key: "unread", label: "Unread" },
    { key: "starred", label: "Starred" }
  ].freeze

  def initialize(current_path:, active_filters:, labels:)
    @current_path = current_path
    @active_filters = active_filters
    @labels = labels
  end

  private

  def chip_url(key, value)
    toggled = @active_filters.dup
    if toggled[key]
      toggled.delete(key)
    else
      toggled[key] = value
    end
    query = toggled.to_query
    query.empty? ? @current_path : "#{@current_path}?#{query}"
  end

  def active?(key)
    @active_filters.key?(key)
  end

  def status_chip_classes(key)
    base = "inline-flex items-center rounded-full px-3 py-1 text-xs font-medium transition-colors"
    if active?(key)
      "#{base} bg-blue-600 text-white hover:bg-blue-700"
    else
      "#{base} border border-gray-300 text-gray-600 hover:bg-gray-50"
    end
  end

  def label_chip_classes(label)
    base = "inline-flex items-center rounded-full px-3 py-1 text-xs font-medium transition-colors"
    if active?("label_id") && @active_filters["label_id"] == label.id.to_s
      color_active_classes(label.color, base)
    else
      "#{base} border border-gray-300 text-gray-600 hover:bg-gray-50"
    end
  end

  def label_active?(label)
    active?("label_id") && @active_filters["label_id"] == label.id.to_s
  end

  def color_active_classes(color, base)
    mapping = {
      "blue" => "bg-blue-600 text-white hover:bg-blue-700",
      "green" => "bg-green-600 text-white hover:bg-green-700",
      "red" => "bg-red-600 text-white hover:bg-red-700",
      "yellow" => "bg-yellow-500 text-white hover:bg-yellow-600",
      "purple" => "bg-purple-600 text-white hover:bg-purple-700",
      "indigo" => "bg-indigo-600 text-white hover:bg-indigo-700"
    }
    "#{base} #{mapping.fetch(color, mapping['blue'])}"
  end
end
```

Create `app/components/filter_chips_component.html.erb`:

```erb
<div class="flex flex-wrap gap-2 px-4 py-2 border-b border-gray-200">
  <% STATUS_FILTERS.each do |filter| %>
    <%= link_to filter[:label],
        chip_url(filter[:key], "1"),
        class: status_chip_classes(filter[:key]),
        data: { turbo_frame: "message_list" } %>
  <% end %>

  <% @labels.each do |label| %>
    <%= link_to label.name,
        chip_url("label_id", label.id.to_s),
        class: label_chip_classes(label),
        data: { turbo_frame: "message_list" } %>
  <% end %>
</div>
```

**Step 4: Run tests to verify they pass**

Run: `bin/rails test test/components/filter_chips_component_test.rb`
Expected: All PASS

**Step 5: Commit**

```bash
git add app/components/filter_chips_component.rb app/components/filter_chips_component.html.erb test/components/filter_chips_component_test.rb
git commit -m "feat: add FilterChipsComponent with status and label chips"
```

---

### Task 4: Wire FilterChipsComponent into MessageListComponent

**Files:**
- Modify: `app/components/message_list_component.rb`
- Modify: `app/components/message_list_component.html.erb`
- Modify: `app/views/messages/index.html.erb`
- Modify: `app/views/messages/message_list_frame.html.erb`

**Step 1: Update MessageListComponent to accept filter data**

In `app/components/message_list_component.rb`, update `initialize`:

```ruby
def initialize(messages:, folder:, current_contact: nil, selected_id: nil, active_filters: {})
  @messages = messages
  @folder = folder
  @current_contact = current_contact
  @selected_id = selected_id
  @active_filters = active_filters
end
```

Add private helper:

```ruby
def current_folder_path
  case @folder
  when "inbox" then helpers.root_path
  when "sent" then helpers.sent_messages_path
  when "archive" then helpers.archive_messages_path
  when "trash" then helpers.trash_messages_path
  else helpers.root_path
  end
end
```

**Step 2: Add filter chips to the template**

In `app/components/message_list_component.html.erb`, after the `</header>` tag (line 7) and before the `<% if @messages.any? %>` (line 9), insert:

```erb
<%= render FilterChipsComponent.new(
  current_path: current_folder_path,
  active_filters: @active_filters,
  labels: Label.all
) %>
```

**Step 3: Pass active_filters from views**

In `app/views/messages/index.html.erb`, update the `MessageListComponent.new` call to include `active_filters`:

```erb
message_list: MessageListComponent.new(
  messages: @messages,
  folder: @folder,
  current_contact: current_contact,
  selected_id: @message&.id,
  active_filters: @active_filters || {}
),
```

In `app/views/messages/message_list_frame.html.erb`, update:

```erb
<%= render MessageListComponent.new(messages: @messages, folder: @folder, active_filters: @active_filters || {}) %>
```

**Step 4: Run the full test suite**

Run: `bin/rails test`
Expected: All PASS

**Step 5: Commit**

```bash
git add app/components/message_list_component.rb app/components/message_list_component.html.erb app/views/messages/index.html.erb app/views/messages/message_list_frame.html.erb
git commit -m "feat: wire filter chips into message list"
```

---

### Task 5: Manual smoke test

**Steps:**
1. Start the dev server: `bin/dev`
2. Navigate to Inbox — verify filter chips (Unread, Starred, and any labels) appear below the header
3. Click "Unread" — verify only unread messages shown, chip is filled blue
4. Click "Unread" again — verify filter removed, all messages shown
5. Click "Starred" — verify only starred messages shown
6. Combine "Unread" + "Starred" — verify AND logic works
7. Click a label chip — verify only messages with that label shown
8. Switch to Sent folder — verify filters reset
9. Apply filter in Sent — verify it works independently
