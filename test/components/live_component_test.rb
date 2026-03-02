# frozen_string_literal: true

require "test_helper"

class LiveComponentTest < ActiveSupport::TestCase
  setup do
    @sender = Contact.create!(name: "Alice", email: "alice@example.com")
    @recipient = Contact.create!(name: "Bob", email: "bob@example.com")
    @message = Message.create!(
      subject: "Test",
      body: "Hello",
      sender: @sender,
      recipient: @recipient,
      label: "inbox"
    )
  end

  # --- dom_id_for ---

  test "dom_id_for without prefix returns standard dom_id" do
    dom_id = MessageRowComponent.dom_id_for(@message)
    assert_equal "message_#{@message.id}", dom_id
  end

  test "dom_id_for with prefix returns prefixed dom_id" do
    dom_id = MessageLabelsComponent.dom_id_for(@message)
    assert_equal "labels_message_#{@message.id}", dom_id
  end

  test "dom_id_prefix is defined on MessageLabelsComponent" do
    assert_equal :labels, MessageLabelsComponent.dom_id_prefix
  end

  test "MessageRowComponent does not define dom_id_prefix" do
    assert_not MessageRowComponent.respond_to?(:dom_id_prefix)
  end

  # --- build_data: dom_id ---

  test "build_data includes prefixed dom_id for component with prefix" do
    data = MessageLabelsComponent.build_data(@message)
    assert_equal "labels_message_#{@message.id}", data["dom_id"]
    assert_equal @message.id, data["id"]
  end

  test "build_data includes standard dom_id for component without prefix" do
    data = MessageRowComponent.build_data(@message)
    assert_equal "message_#{@message.id}", data["dom_id"]
  end

  # --- build_data: const-based collection evaluation ---

  test "build_data evaluates const-based collection expressions" do
    Label.create!(name: "Important", color: "red")
    Label.create!(name: "Work", color: "blue")

    data = MessageLabelsComponent.build_data(@message)

    # Find the collection key — it should have an array value
    collection_entry = data.find { |_k, v| v.is_a?(Array) }
    assert_not_nil collection_entry, "Expected a collection (array) in build_data, got keys: #{data.keys}"

    _, items = collection_entry
    assert_equal Label.order(:name).count, items.size,
      "Expected collection to have #{Label.order(:name).count} items"
  end

  test "build_data collection items contain per-item computed fields" do
    Label.create!(name: "Important", color: "red")

    data = MessageLabelsComponent.build_data(@message)
    collection_entry = data.find { |_k, v| v.is_a?(Array) }
    assert_not_nil collection_entry

    _key, items = collection_entry
    item = items.first
    assert item.is_a?(Hash), "Expected each collection item to be a hash"
    assert_not_empty item, "Expected per-item computed fields"
  end

  # --- execute_action ---

  test "execute_action invokes the named action" do
    label = Label.create!(name: "Urgent", color: "red")
    MessageLabelsComponent.execute_action(:add_label, @message, { label_id: label.id })
    @message.reload
    assert_includes @message.labels, label
  end

  test "execute_action raises for unknown action" do
    assert_raises(ArgumentError) do
      MessageLabelsComponent.execute_action(:nonexistent, @message)
    end
  end

  # --- live_action_token round-trip ---

  test "live_action_token can be verified" do
    token = MessageLabelsComponent.live_action_token(@message)
    verifier = Rails.application.message_verifier(:live_component_action)
    payload = verifier.verify(token, purpose: :live_component_action)

    assert_equal "MessageLabelsComponent", payload["c"]
    assert_equal "Message", payload["m"]
    assert_equal @message.id, payload["r"]
  end

  # --- build_data: thread messages collection ---

  test "build_data for MessageDetailComponent includes thread messages collection" do
    data = MessageDetailComponent.build_data(@message)
    collection_entry = data.find { |_k, v| v.is_a?(Array) }
    assert_not_nil collection_entry, "Expected a collection (array) for thread messages in build_data"
  end

  test "build_data thread messages collection contains per-item computed fields" do
    data = MessageDetailComponent.build_data(@message)
    collection_entry = data.find { |_k, v| v.is_a?(Array) }
    assert_not_nil collection_entry

    _key, items = collection_entry
    assert_equal 1, items.size, "Expected one message in the thread"
    item = items.first
    assert item.is_a?(Hash), "Expected each thread message item to be a hash"
    assert_not_empty item, "Expected per-item computed fields"
  end

  test "build_data for MessageDetailComponent has no raw button HTML blob" do
    data = MessageDetailComponent.build_data(@message)
    button_blob = data.values.find { |v| v.is_a?(String) && v.include?("<button") && v.include?("Reply") }
    assert_nil button_blob, "Expected button to be inlined in template, not a server-rendered HTML blob"
  end

  test "build_data for MessageDetailComponent renders nested LiveComponent with wrapper" do
    data = MessageDetailComponent.build_data(@message)
    labels_html = data.values.find { |v| v.is_a?(String) && v.include?("data-controller=\"live-renderer\"") }
    assert_not_nil labels_html, "Expected MessageLabelsComponent with live-renderer wrapper in build_data"
    assert_includes labels_html, "labels_message_#{@message.id}"
  end

  test "build_data for MessageDetailComponent has no nil render expressions" do
    data = MessageDetailComponent.build_data(@message)
    nil_keys = data.select { |_k, v| v.nil? }.keys.reject { |k| k.start_with?("_nc") }
    assert_empty nil_keys, "Expected no nil values in build_data, but got nil for: #{nil_keys.join(', ')}"
  end

  # --- dom_id_for: MessageDetailComponent ---

  test "MessageDetailComponent dom_id_for returns prefixed dom_id" do
    assert_equal "detail_message_#{@message.id}", MessageDetailComponent.dom_id_for(@message)
  end

  test "MessageDetailComponent and MessageRowComponent have distinct dom_ids" do
    detail_id = MessageDetailComponent.dom_id_for(@message)
    row_id = MessageRowComponent.dom_id_for(@message)
    assert_not_equal detail_id, row_id
  end

  # --- _broadcast_config ---

  test "broadcasts sets _broadcast_config on component" do
    config = MessageRowComponent._broadcast_config
    assert_not_nil config
    assert config[:stream].is_a?(Proc)
    assert_equal "message_items", config[:prepend_target]
  end

  test "component without broadcasts has nil _broadcast_config" do
    assert_nil AvatarComponent._broadcast_config
  end

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

  # --- wrapper: client state & initial data ---

  test "render_in embeds client state as data attribute" do
    component = MessageRowComponent.new(message: @message, selected: true)
    html = component.render_in(view_context_for_test)

    assert_match(/data-live-renderer-state-value/, html)
    # Should contain the initial client state JSON
    state_match = html.match(/data-live-renderer-state-value="([^"]*)"/)
    assert_not_nil state_match
    state = JSON.parse(CGI.unescapeHTML(state_match[1]))
    assert_equal true, state["selected"]
  end

  test "render_in embeds initial server data as data attribute" do
    component = MessageRowComponent.new(message: @message, selected: false)
    html = component.render_in(view_context_for_test)

    assert_match(/data-live-renderer-data-value/, html)
    data_match = html.match(/data-live-renderer-data-value="([^"]*)"/)
    assert_not_nil data_match
    data = JSON.parse(CGI.unescapeHTML(data_match[1]))
    assert_equal "message_#{@message.id}", data["dom_id"]
  end

  test "render_in for component without client_state omits state attribute" do
    component = MessageLabelsComponent.new(message: @message)
    html = component.render_in(view_context_for_test)

    assert_no_match(/data-live-renderer-state-value/, html)
  end

  # --- template_element_id ---

  test "template_element_id is derived from class name" do
    assert_equal "message_labels_component_template", MessageLabelsComponent.template_element_id
    assert_equal "message_row_component_template", MessageRowComponent.template_element_id
  end

  # --- render_in edge cases ---

  test "render_in returns inner html when no _live_model_attr" do
    component = AvatarComponent.new(contact: @sender, size: :md)
    html = component.render_in(view_context_for_test)

    assert_not_includes html, "data-controller=\"live-renderer\""
  end

  test "render_in skips wrapper when @_skip_live_wrapper is true" do
    component = MessageLabelsComponent.new(message: @message)
    component.instance_variable_set(:@_skip_live_wrapper, true)
    html = component.render_in(view_context_for_test)

    assert_not_includes html, "data-controller=\"live-renderer\""
  end

  # --- template_script_tag deduplication ---

  test "template_script_tag emits once per class per view context" do
    vc = view_context_for_test
    first = MessageRowComponent.template_script_tag(vc)
    second = MessageRowComponent.template_script_tag(vc)

    assert_not_nil first
    assert_nil second
  end

  test "template_script_tag emits separately for different classes" do
    vc = view_context_for_test
    first = MessageRowComponent.template_script_tag(vc)
    second = MessageLabelsComponent.template_script_tag(vc)

    assert_not_nil first
    assert_not_nil second
  end

  test "template_script_tag includes correct id" do
    vc = view_context_for_test
    script = MessageRowComponent.template_script_tag(vc)
    assert_includes script, %(id="message_row_component_template")
  end

  # --- encoded_template ---

  test "encoded_template returns base64 when debug is off" do
    original = LiveComponent.debug
    LiveComponent.debug = false
    # Clear memoized value
    MessageRowComponent.instance_variable_set(:@encoded_template, nil)

    encoded = MessageRowComponent.encoded_template
    assert_match(/\A[A-Za-z0-9+\/\n]+=*\z/, encoded)
  ensure
    LiveComponent.debug = original
    MessageRowComponent.instance_variable_set(:@encoded_template, nil)
  end

  # --- live_action with params ---

  test "execute_action filters params to allowed list" do
    label = Label.create!(name: "Test", color: "red")
    # add_label allows :label_id param
    MessageLabelsComponent.execute_action(:add_label, @message, { label_id: label.id, evil: "hack" })
    @message.reload
    assert_includes @message.labels, label
  end

  test "execute_action calls action without params when none declared" do
    @message.update!(starred: false)
    MessageRowComponent.execute_action(:toggle_star, @message)
    assert @message.reload.starred?
  end

  # --- expression_field_map ---

  test "expression_field_map returns source-to-key mapping" do
    map = MessageRowComponent.expression_field_map
    assert_kind_of Hash, map
    # The map inverts expressions: Ruby source → JS key
    assert_equal "v2", map["@message.sender.name"]
    assert_equal "v9", map["@message.subject"]
  end

  # --- build_data_for_nested ---

  test "build_data_for_nested evaluates expressions with provided kwargs" do
    data = MessageLabelsComponent.build_data_for_nested(message: @message)
    assert data.is_a?(Hash)
    assert_not_empty data
  end

  private

  def view_context_for_test
    controller = ApplicationController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.view_context
  end
end
