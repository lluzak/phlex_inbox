# frozen_string_literal: true

require "test_helper"

class FilterChipsComponentTest < ViewComponent::TestCase
  setup do
    @label = Label.create!(name: "work", color: "blue")
  end

  test "renders unread and starred chips" do
    component = FilterChipsComponent.new(
      current_path: "/",
      active_filters: {},
      labels: [@label]
    )
    render_inline(component)

    assert_selector "a", text: "Unread"
    assert_selector "a", text: "Starred"
  end

  test "renders label chips" do
    component = FilterChipsComponent.new(
      current_path: "/",
      active_filters: {},
      labels: [@label]
    )
    render_inline(component)

    assert_selector "a", text: "work"
  end

  test "active unread chip links to path without unread param" do
    component = FilterChipsComponent.new(
      current_path: "/",
      active_filters: { "unread" => "1" },
      labels: []
    )
    render_inline(component)

    unread_link = page.find("a", text: "Unread")
    assert_equal "/", unread_link[:href]
  end

  test "inactive unread chip links to path with unread param" do
    component = FilterChipsComponent.new(
      current_path: "/",
      active_filters: {},
      labels: []
    )
    render_inline(component)

    unread_link = page.find("a", text: "Unread")
    assert_equal "/?unread=1", unread_link[:href]
  end

  test "active chip has filled style" do
    component = FilterChipsComponent.new(
      current_path: "/",
      active_filters: { "unread" => "1" },
      labels: []
    )
    render_inline(component)

    unread_link = page.find("a", text: "Unread")
    assert_includes unread_link[:class], "bg-blue-600"
  end

  test "inactive chip has outline style" do
    component = FilterChipsComponent.new(
      current_path: "/",
      active_filters: {},
      labels: []
    )
    render_inline(component)

    unread_link = page.find("a", text: "Unread")
    assert_includes unread_link[:class], "border-gray-300"
  end
end
