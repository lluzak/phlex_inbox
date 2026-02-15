# frozen_string_literal: true

require "test_helper"

class BroadcastableTest < ActiveSupport::TestCase
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

  # --- broadcast_component_classes ---

  test "Message has three broadcast component classes" do
    assert_equal 3, Message.broadcast_component_classes.size
  end

  test "broadcast component classes include MessageRowComponent, MessageDetailComponent and MessageLabelsComponent" do
    assert_includes Message.broadcast_component_classes, MessageRowComponent
    assert_includes Message.broadcast_component_classes, MessageDetailComponent
    assert_includes Message.broadcast_component_classes, MessageLabelsComponent
  end

  test "MessageRowComponent config has prepend_target" do
    assert_equal "message_items", MessageRowComponent._broadcast_config[:prepend_target]
  end

  test "MessageLabelsComponent config has no prepend_target" do
    assert_nil MessageLabelsComponent._broadcast_config[:prepend_target]
  end

  # --- dom_id_for_component ---

  test "dom_id_for_component uses component dom_id_for when available" do
    dom_id = @message.send(:dom_id_for_component, MessageLabelsComponent)
    assert_equal "labels_message_#{@message.id}", dom_id
  end

  test "dom_id_for_component falls back to standard dom_id" do
    dom_id = @message.send(:dom_id_for_component, MessageRowComponent)
    assert_equal "message_#{@message.id}", dom_id
  end

  # --- broadcast_live_update builds correct data per component ---

  test "build_data produces distinct dom_ids for each component" do
    row_data = MessageRowComponent.build_data(@message)
    labels_data = MessageLabelsComponent.build_data(@message)

    assert_equal "message_#{@message.id}", row_data["dom_id"]
    assert_equal "labels_message_#{@message.id}", labels_data["dom_id"]
    assert_not_equal row_data["dom_id"], labels_data["dom_id"]
  end

  # --- broadcast_live_update via capture ---

  test "broadcast_live_update broadcasts for each config" do
    broadcasts = capture_live_broadcasts { @message.send(:broadcast_live_update) }

    assert_equal 3, broadcasts.size, "Expected 3 broadcasts (one per config), got #{broadcasts.size}"
    broadcasts.each do |b|
      assert_equal :update, b[:action]
      assert b[:data].is_a?(Hash)
      assert b[:data].key?("dom_id")
    end
  end

  test "broadcast_live_update sends correct dom_ids" do
    broadcasts = capture_live_broadcasts { @message.send(:broadcast_live_update) }

    dom_ids = broadcasts.map { |b| b[:data]["dom_id"] }
    assert_includes dom_ids, "message_#{@message.id}"
    assert_includes dom_ids, "labels_message_#{@message.id}"
  end

  # --- broadcast_live_destroy ---

  test "broadcast_live_destroy sends distinct dom_ids" do
    broadcasts = capture_live_broadcasts { @message.send(:broadcast_live_destroy) }

    dom_ids = broadcasts.map { |b| b[:data]["dom_id"] }
    assert_includes dom_ids, "message_#{@message.id}"
    assert_includes dom_ids, "labels_message_#{@message.id}"
  end

  # --- label touch integration ---

  test "adding a label touches message and triggers broadcasts" do
    label = Label.create!(name: "Urgent", color: "red")

    broadcasts = capture_live_broadcasts { @message.labels << label }

    assert broadcasts.size >= 2, "Expected at least 2 broadcasts, got #{broadcasts.size}"

    dom_ids = broadcasts.map { |b| b[:data]["dom_id"] }
    assert_includes dom_ids, "message_#{@message.id}"
    assert_includes dom_ids, "labels_message_#{@message.id}"
  end

  private

  # Temporarily replace LiveComponentChannel.broadcast_data to capture calls
  def capture_live_broadcasts
    broadcasts = []
    original = LiveComponentChannel.method(:broadcast_data)

    LiveComponentChannel.define_singleton_method(:broadcast_data) do |stream, action:, data:|
      broadcasts << { stream: stream, action: action, data: data }
    end

    yield

    broadcasts
  ensure
    LiveComponentChannel.define_singleton_method(:broadcast_data, original)
  end
end
