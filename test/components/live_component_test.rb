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

  # --- template_element_id ---

  test "template_element_id is derived from class name" do
    assert_equal "message_labels_component_template", MessageLabelsComponent.template_element_id
    assert_equal "message_row_component_template", MessageRowComponent.template_element_id
  end
end
