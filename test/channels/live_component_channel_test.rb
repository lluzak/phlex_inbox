# frozen_string_literal: true

require "test_helper"

class LiveComponentChannelTest < ActionCable::Channel::TestCase
  setup do
    @contact = contacts(:one)
    @contact.update!(name: "Test User", email: "you@example.com")

    @other_contact = contacts(:two)
    @other_contact.update!(name: "Other User", email: "other@example.com")

    @message = messages(:one)
    @message.update!(
      subject: "Test Subject",
      body: "Test body content",
      label: "inbox",
      sender: @other_contact,
      recipient: @contact,
      read_at: nil,
      starred: false,
      replied_to: nil
    )

    signed_stream = Turbo::StreamsChannel.signed_stream_name([@contact, :messages])
    stub_connection(current_contact: @contact)
    subscribe(signed_stream_name: signed_stream)
  end

  test "request_update transmits update when message matches filters" do
    perform :request_update, {
      "component" => "MessageRowComponent",
      "record_id" => @message.id,
      "dom_id" => "message_#{@message.id}",
      "params" => {}
    }

    assert_equal 1, transmissions.size
    result = transmissions.last
    assert_equal "render", result["action"]
    assert_equal @message.id, result["data"]["id"]
  end

  test "request_update transmits remove when message does not match unread filter" do
    @message.update!(read_at: Time.current)

    perform :request_update, {
      "component" => "MessageRowComponent",
      "record_id" => @message.id,
      "dom_id" => "message_#{@message.id}",
      "params" => { "unread" => "1" }
    }

    assert_equal 1, transmissions.size
    result = transmissions.last
    assert_equal "remove", result["action"]
    assert_equal "message_#{@message.id}", result["dom_id"]
  end

  test "request_update transmits remove when message does not match starred filter" do
    perform :request_update, {
      "component" => "MessageRowComponent",
      "record_id" => @message.id,
      "dom_id" => "message_#{@message.id}",
      "params" => { "starred" => "1" }
    }

    assert_equal 1, transmissions.size
    result = transmissions.last
    assert_equal "remove", result["action"]
    assert_equal "message_#{@message.id}", result["dom_id"]
  end

  test "request_update transmits remove when message does not match label filter" do
    label = Label.create!(name: "Important", color: "red")

    perform :request_update, {
      "component" => "MessageRowComponent",
      "record_id" => @message.id,
      "dom_id" => "message_#{@message.id}",
      "params" => { "label_ids" => [label.id] }
    }

    assert_equal 1, transmissions.size
    result = transmissions.last
    assert_equal "remove", result["action"]
    assert_equal "message_#{@message.id}", result["dom_id"]
  end

  test "request_update transmits update when message matches label filter" do
    label = Label.create!(name: "Important", color: "red")
    Labeling.create!(message: @message, label: label)

    perform :request_update, {
      "component" => "MessageRowComponent",
      "record_id" => @message.id,
      "dom_id" => "message_#{@message.id}",
      "params" => { "label_ids" => [label.id] }
    }

    assert_equal 1, transmissions.size
    result = transmissions.last
    assert_equal "render", result["action"]
    assert_equal @message.id, result["data"]["id"]
  end

  test "request_update does nothing for nonexistent record" do
    perform :request_update, {
      "component" => "MessageRowComponent",
      "record_id" => 999_999,
      "dom_id" => "message_999999",
      "params" => {}
    }

    assert_empty transmissions
  end

  # --- broadcast_data class method ---

  test "broadcast_data broadcasts uncompressed payload by default" do
    original = LiveComponentChannel.compress
    LiveComponentChannel.compress = false

    stream = [@contact, :messages]
    data = { "dom_id" => "message_#{@message.id}", "id" => @message.id }

    signed = Turbo::StreamsChannel.signed_stream_name(stream)
    stream_name = Turbo::StreamsChannel.verified_stream_name(signed)

    assert_broadcasts(stream_name, 1) do
      LiveComponentChannel.broadcast_data(stream, action: :update, data: data)
    end
  ensure
    LiveComponentChannel.compress = original
  end

  test "broadcast_data broadcasts compressed payload when compress enabled" do
    original = LiveComponentChannel.compress
    LiveComponentChannel.compress = true

    stream = [@contact, :messages]
    data = { "dom_id" => "message_#{@message.id}", "id" => @message.id }

    signed = Turbo::StreamsChannel.signed_stream_name(stream)
    stream_name = Turbo::StreamsChannel.verified_stream_name(signed)

    assert_broadcasts(stream_name, 1) do
      LiveComponentChannel.broadcast_data(stream, action: :update, data: data)
    end
  ensure
    LiveComponentChannel.compress = original
  end

  # --- request_update: component-level (no record_id) ---

  test "request_update without record_id does component-level update" do
    perform :request_update, {
      "component" => "MessageRowComponent",
      "dom_id" => "message_#{@message.id}",
      "params" => { "record_id" => @message.id.to_s }
    }

    assert_equal 1, transmissions.size
    result = transmissions.last
    assert_equal "render", result["action"]
  end

  # --- request_update: matching filters ---

  test "request_update transmits update when message matches unread filter" do
    @message.update!(read_at: nil) # ensure unread

    perform :request_update, {
      "component" => "MessageRowComponent",
      "record_id" => @message.id,
      "dom_id" => "message_#{@message.id}",
      "params" => { "unread" => "1" }
    }

    assert_equal 1, transmissions.size
    assert_equal "render", transmissions.last["action"]
  end

  test "request_update transmits update when message matches starred filter" do
    @message.update!(starred: true)

    perform :request_update, {
      "component" => "MessageRowComponent",
      "record_id" => @message.id,
      "dom_id" => "message_#{@message.id}",
      "params" => { "starred" => "1" }
    }

    assert_equal 1, transmissions.size
    assert_equal "render", transmissions.last["action"]
  end
end
