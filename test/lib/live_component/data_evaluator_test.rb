# frozen_string_literal: true

require "test_helper"

class LiveComponent::DataEvaluatorTest < ActiveSupport::TestCase
  setup do
    @sender = Contact.create!(name: "Alice", email: "alice@example.com")
    @recipient = Contact.create!(name: "Bob", email: "bob@example.com")
    @message = Message.create!(
      subject: "Test Subject",
      body: "Hello",
      sender: @sender,
      recipient: @recipient,
      label: "inbox"
    )
  end

  # --- evaluate: ivar access ---

  test "evaluate resolves ivar chain on record" do
    evaluator = LiveComponent::DataEvaluator.new(:message, @message, component_class: MessageRowComponent)
    result = evaluator.evaluate("@message.subject")
    assert_equal "Test Subject", result
  end

  test "evaluate resolves nested ivar chain" do
    evaluator = LiveComponent::DataEvaluator.new(:message, @message, component_class: MessageRowComponent)
    result = evaluator.evaluate("@message.sender.name")
    assert_equal "Alice", result
  end

  # --- evaluate: ActionView helpers ---

  test "evaluate can call time_ago_in_words" do
    evaluator = LiveComponent::DataEvaluator.new(:message, @message, component_class: MessageRowComponent)
    result = evaluator.evaluate("time_ago_in_words(@message.created_at)")
    assert result.is_a?(String)
    assert result.present?
  end

  test "evaluate can call truncate" do
    evaluator = LiveComponent::DataEvaluator.new(:message, @message, component_class: MessageRowComponent)
    result = evaluator.evaluate("truncate(@message.body, length: 3)")
    assert_equal "...", result
  end

  # --- evaluate: NameError fallback to component delegate ---

  test "evaluate delegates to component for unknown methods" do
    evaluator = LiveComponent::DataEvaluator.new(:message, @message, component_class: MessageRowComponent)
    # avatar_color is defined on the component, not on DataEvaluator
    result = evaluator.evaluate("avatar_color(@message.sender)")
    assert result.is_a?(String)
  end

  # --- evaluate: error handling ---

  test "evaluate returns nil for completely invalid expression" do
    evaluator = LiveComponent::DataEvaluator.new(:message, @message, component_class: MessageRowComponent)
    result = evaluator.evaluate("nonexistent_object.foo.bar")
    assert_nil result
  end

  # --- evaluate: constant expressions ---

  test "evaluate resolves constant expression" do
    Label.create!(name: "Test", color: "blue")
    evaluator = LiveComponent::DataEvaluator.new(:message, @message, component_class: MessageLabelsComponent)
    result = evaluator.evaluate("Label.count")
    assert_equal Label.count, result
  end
end
