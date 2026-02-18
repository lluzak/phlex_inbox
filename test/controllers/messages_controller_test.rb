# frozen_string_literal: true

require "test_helper"

class MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Message.delete_all
    Labeling.delete_all
    Label.delete_all
    Contact.delete_all

    @sender = Contact.create!(name: "Alice", email: "alice@example.com")
    @recipient = Contact.create!(name: "You", email: "you@example.com")
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

  test "index with label_ids filters by label" do
    label = Label.create!(name: "work", color: "blue")
    labeled_msg = Message.create!(subject: "Work", body: "Body", sender: @sender, recipient: @recipient, label: "inbox")
    labeled_msg.labels << label
    unlabeled_msg = Message.create!(subject: "Other", body: "Body", sender: @sender, recipient: @recipient, label: "inbox")

    get root_path(label_ids: [label.id])
    assert_response :success
    assert_select "[id='#{ActionView::RecordIdentifier.dom_id(labeled_msg)}']"
    assert_select "[id='#{ActionView::RecordIdentifier.dom_id(unlabeled_msg)}']", count: 0
  end

  test "index with multiple label_ids uses AND logic" do
    work = Label.create!(name: "work", color: "blue")
    urgent = Label.create!(name: "urgent", color: "red")
    both_msg = Message.create!(subject: "Both", body: "Body", sender: @sender, recipient: @recipient, label: "inbox")
    both_msg.labels << work
    both_msg.labels << urgent
    only_work_msg = Message.create!(subject: "Work only", body: "Body", sender: @sender, recipient: @recipient, label: "inbox")
    only_work_msg.labels << work

    get root_path(label_ids: [work.id, urgent.id])
    assert_response :success
    assert_select "[id='#{ActionView::RecordIdentifier.dom_id(both_msg)}']"
    assert_select "[id='#{ActionView::RecordIdentifier.dom_id(only_work_msg)}']", count: 0
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
