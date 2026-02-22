# frozen_string_literal: true

require "test_helper"

class LiveComponentActionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sender = Contact.create!(name: "Alice", email: "alice@example.com")
    @recipient = Contact.create!(name: "Bob", email: "bob@example.com")
    @message = Message.create!(
      subject: "Test",
      body: "Hello",
      sender: @sender,
      recipient: @recipient,
      label: "inbox",
      starred: false
    )
  end

  test "create executes action with valid token and returns ok" do
    token = MessageRowComponent.live_action_token(@message)

    post live_component_actions_path, params: {
      token: token,
      action_name: "toggle_star"
    }

    assert_response :ok
    assert @message.reload.starred?
  end

  test "create with params passes filtered params to action" do
    label = Label.create!(name: "Urgent", color: "red")
    token = MessageLabelsComponent.live_action_token(@message)

    post live_component_actions_path, params: {
      token: token,
      action_name: "add_label",
      params: { label_id: label.id }
    }

    assert_response :ok
    assert_includes @message.reload.labels, label
  end

  test "create with invalid token returns 404" do
    post live_component_actions_path, params: {
      token: "invalid_token",
      action_name: "toggle_star"
    }

    assert_response :not_found
  end

  test "create with tampered token returns 404" do
    token = MessageRowComponent.live_action_token(@message)
    tampered = token + "x"

    post live_component_actions_path, params: {
      token: tampered,
      action_name: "toggle_star"
    }

    assert_response :not_found
  end
end
