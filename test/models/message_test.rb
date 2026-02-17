require "test_helper"

class MessageTest < ActiveSupport::TestCase
  setup do
    @sender = Contact.create!(name: "Alice", email: "alice@example.com")
    @recipient = Contact.create!(name: "Bob", email: "bob@example.com")
  end

  test "mark_as_read! sets read_at" do
    msg = Message.create!(subject: "Hi", body: "Hello", sender: @sender, recipient: @recipient)
    assert_nil msg.read_at
    msg.mark_as_read!
    assert_not_nil msg.read_at
  end

  test "toggle_starred! flips starred" do
    msg = Message.create!(subject: "Hi", body: "Hello", sender: @sender, recipient: @recipient)
    assert_not msg.starred
    msg.toggle_starred!
    assert msg.starred
    msg.toggle_starred!
    assert_not msg.starred
  end

  test "preview truncates body" do
    msg = Message.new(body: "a" * 200)
    assert_equal 100, msg.preview.length
  end

  test "scopes filter by label" do
    msg = Message.create!(subject: "Hi", body: "Hello", sender: @sender, recipient: @recipient, label: "inbox")
    assert_includes Message.inbox, msg
    assert_not_includes Message.sent_box, msg
  end

  test "filter_by_label scope filters by label_id" do
    msg = Message.create!(subject: "Hi", body: "Hello", sender: @sender, recipient: @recipient)
    label = Label.create!(name: "work", color: "blue")
    msg.labels << label

    unlabeled = Message.create!(subject: "Other", body: "World", sender: @sender, recipient: @recipient)

    assert_includes Message.filter_by_label(label.id), msg
    assert_not_includes Message.filter_by_label(label.id), unlabeled
  end

  test "validates label inclusion" do
    msg = Message.new(subject: "Hi", body: "Hello", sender: @sender, recipient: @recipient, label: "bogus")
    assert_not msg.valid?
  end
end
