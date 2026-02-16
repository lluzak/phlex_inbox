# frozen_string_literal: true

require "test_helper"

class MessageLabelsComponentTest < ActiveSupport::TestCase
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

  # --- add_label action ---

  test "add_label adds a label to the message" do
    label = Label.create!(name: "Important", color: "blue")

    MessageLabelsComponent.execute_action(:add_label, @message, { label_id: label.id })
    @message.reload

    assert_includes @message.labels, label
  end

  test "add_label is idempotent" do
    label = Label.create!(name: "Important", color: "blue")
    @message.labels << label

    assert_no_difference -> { Labeling.count } do
      MessageLabelsComponent.execute_action(:add_label, @message, { label_id: label.id })
    end
  end

  # --- remove_label action ---

  test "remove_label removes a label from the message" do
    label = Label.create!(name: "Important", color: "blue")
    @message.labels << label

    MessageLabelsComponent.execute_action(:remove_label, @message, { label_id: label.id })
    @message.reload

    assert_not_includes @message.labels, label
  end

  test "remove_label is safe when label not present" do
    label = Label.create!(name: "Important", color: "blue")

    assert_nothing_raised do
      MessageLabelsComponent.execute_action(:remove_label, @message, { label_id: label.id })
    end
  end

  # --- compiled template ---

  test "compiled template extracts labels collection" do
    data = MessageLabelsComponent.compiled_data

    collection_expressions = data[:expressions].select { |k, _| data[:collection_computed].key?(k) }
    assert_not_empty collection_expressions,
      "Expected at least one collection expression, got expressions: #{data[:expressions]}"

    collection_source = collection_expressions.values.first
    assert_match(/labels/, collection_source)
  end

  test "compiled template has block computed for label properties" do
    data = MessageLabelsComponent.compiled_data
    cc = data[:collection_computed]
    assert_not_empty cc

    collection_key = cc.keys.first
    computed = cc[collection_key]
    assert_equal "label", computed[:block_var]

    expr_sources = computed[:expressions].values.map { |info| info[:source] }
    assert expr_sources.any? { |s| s.include?("label") },
      "Expected block computed expressions referencing label, got: #{expr_sources}"
  end

  test "compiled template has block computed for helper methods" do
    data = MessageLabelsComponent.compiled_data
    cc = data[:collection_computed]
    collection_key = cc.keys.first
    expr_sources = cc[collection_key][:expressions].values.map { |info| info[:source] }

    assert expr_sources.any? { |s| s.include?("label_action") },
      "Expected label_action in block computed, got: #{expr_sources}"
    assert expr_sources.any? { |s| s.include?("label_css") },
      "Expected label_css in block computed, got: #{expr_sources}"
    assert expr_sources.any? { |s| s.include?("label_text") },
      "Expected label_text in block computed, got: #{expr_sources}"
  end

  test "compiled JS does not contain raw Ruby" do
    data = MessageLabelsComponent.compiled_data
    assert_no_match(/@labels/, data[:js_body])
    assert_no_match(/@message/, data[:js_body])
    assert_no_match(/LabelBadgeComponent/, data[:js_body])
  end

  # --- build_data with labels ---

  test "build_data returns collection with correct item count" do
    Label.create!(name: "Important", color: "blue")
    Label.create!(name: "Work", color: "green")

    data = MessageLabelsComponent.build_data(@message)

    collection = data.find { |_k, v| v.is_a?(Array) }
    assert_not_nil collection, "Expected array in build_data"

    _key, items = collection
    assert_equal Label.count, items.size
  end

  test "build_data collection items contain per-item computed hashes" do
    Label.create!(name: "Important", color: "blue")

    data = MessageLabelsComponent.build_data(@message)
    collection = data.find { |_k, v| v.is_a?(Array) }
    assert_not_nil collection

    _key, items = collection
    item = items.first
    assert item.is_a?(Hash), "Expected each collection item to be a hash, got: #{item.class}"
    assert_not_empty item, "Expected per-item computed fields to be populated"
  end

  test "build_data includes prefixed dom_id" do
    data = MessageLabelsComponent.build_data(@message)
    assert_equal "labels_message_#{@message.id}", data["dom_id"]
  end

  test "build_data marks applied labels as remove_label action" do
    label = Label.create!(name: "Work", color: "blue")
    @message.labels << label

    data = MessageLabelsComponent.build_data(@message)
    collection = data.find { |_k, v| v.is_a?(Array) }
    _key, items = collection

    applied_item = items.find { |item| item.values.include?(label.id.to_s) }
    assert_not_nil applied_item, "Expected to find the applied label in collection"
    assert applied_item.values.include?("remove_label"),
      "Expected applied label to have remove_label action"
  end

  test "build_data marks unapplied labels as add_label action" do
    label = Label.create!(name: "Work", color: "blue")

    data = MessageLabelsComponent.build_data(@message)
    collection = data.find { |_k, v| v.is_a?(Array) }
    _key, items = collection

    unapplied_item = items.find { |item| item.values.include?(label.id.to_s) }
    assert_not_nil unapplied_item, "Expected to find the label in collection"
    assert unapplied_item.values.include?("add_label"),
      "Expected unapplied label to have add_label action"
  end

  test "build_data uses colored CSS for applied labels" do
    label = Label.create!(name: "Work", color: "blue")
    @message.labels << label

    data = MessageLabelsComponent.build_data(@message)
    collection = data.find { |_k, v| v.is_a?(Array) }
    _key, items = collection

    applied_item = items.find { |item| item.values.include?(label.id.to_s) }
    assert applied_item.values.any? { |v| v.include?("bg-blue-100") },
      "Expected applied label to have colored CSS classes"
  end

  test "build_data uses gray CSS for unapplied labels" do
    label = Label.create!(name: "Work", color: "blue")

    data = MessageLabelsComponent.build_data(@message)
    collection = data.find { |_k, v| v.is_a?(Array) }
    _key, items = collection

    unapplied_item = items.find { |item| item.values.include?(label.id.to_s) }
    assert unapplied_item.values.any? { |v| v.include?("bg-gray-100") },
      "Expected unapplied label to have gray CSS classes"
  end

  test "build_data includes dismiss marker for applied labels" do
    label = Label.create!(name: "Work", color: "blue")
    @message.labels << label

    data = MessageLabelsComponent.build_data(@message)
    collection = data.find { |_k, v| v.is_a?(Array) }
    _key, items = collection

    applied_item = items.find { |item| item.values.include?(label.id.to_s) }
    assert applied_item.values.any? { |v| v.include?("\u00D7") },
      "Expected applied label text to include dismiss marker"
  end
end
