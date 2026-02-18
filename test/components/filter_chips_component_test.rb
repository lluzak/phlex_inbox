# frozen_string_literal: true

require "test_helper"

class FilterChipsComponentTest < ViewComponent::TestCase
  setup do
    @label = Label.create!(name: "work", color: "blue")
  end

  test "renders unread and starred chips" do
    render_inline(FilterChipsComponent.new(current_path: "/", active_filters: {}, labels: [@label]))

    assert_selector "a", text: "Unread"
    assert_selector "a", text: "Starred"
  end

  test "renders label chips" do
    render_inline(FilterChipsComponent.new(current_path: "/", active_filters: {}, labels: [@label]))

    assert_selector "a", text: "work"
  end

  test "renders separator between status and label chips" do
    render_inline(FilterChipsComponent.new(current_path: "/", active_filters: {}, labels: [@label]))

    assert_selector "span.bg-gray-300"
  end

  test "active unread chip links to path without unread param" do
    render_inline(FilterChipsComponent.new(current_path: "/", active_filters: { "unread" => "1" }, labels: []))

    unread_link = page.find("a", text: "Unread")
    assert_equal "/", unread_link[:href]
  end

  test "inactive unread chip links to path with unread param" do
    render_inline(FilterChipsComponent.new(current_path: "/", active_filters: {}, labels: []))

    unread_link = page.find("a", text: "Unread")
    assert_equal "/?unread=1", unread_link[:href]
  end

  test "active chip has filled style" do
    render_inline(FilterChipsComponent.new(current_path: "/", active_filters: { "unread" => "1" }, labels: []))

    unread_link = page.find("a", text: "Unread")
    assert_includes unread_link[:class], "bg-blue-600"
  end

  test "inactive chip has outline style" do
    render_inline(FilterChipsComponent.new(current_path: "/", active_filters: {}, labels: []))

    unread_link = page.find("a", text: "Unread")
    assert_includes unread_link[:class], "border-gray-300"
  end

  test "clicking label adds it to label_ids array" do
    render_inline(FilterChipsComponent.new(current_path: "/", active_filters: {}, labels: [@label]))

    label_link = page.find("a", text: "work")
    assert_includes label_link[:href], "label_ids[]=#{@label.id}"
  end

  test "clicking active label removes it from label_ids array" do
    render_inline(FilterChipsComponent.new(
      current_path: "/",
      active_filters: { "label_ids" => [@label.id.to_s] },
      labels: [@label]
    ))

    label_link = page.find("a", text: "work")
    assert_equal "/", label_link[:href]
  end

  test "clicking second label adds it while keeping first" do
    other_label = Label.create!(name: "personal", color: "green")
    render_inline(FilterChipsComponent.new(
      current_path: "/",
      active_filters: { "label_ids" => [@label.id.to_s] },
      labels: [@label, other_label]
    ))

    other_link = page.find("a", text: "personal")
    assert_includes other_link[:href], "label_ids[]=#{@label.id}"
    assert_includes other_link[:href], "label_ids[]=#{other_label.id}"
  end
end
