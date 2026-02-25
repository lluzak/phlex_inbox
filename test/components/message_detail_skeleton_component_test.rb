# frozen_string_literal: true

require "test_helper"

class MessageDetailSkeletonComponentTest < ViewComponent::TestCase
  test "renders skeleton with animate-pulse" do
    render_inline(MessageDetailSkeletonComponent.new)

    assert_selector ".animate-pulse"
  end

  test "renders placeholder elements for action bar, subject, and body" do
    render_inline(MessageDetailSkeletonComponent.new)

    assert_selector ".border-b .bg-gray-200.rounded", minimum: 3
    assert_selector ".bg-gray-200.rounded.h-6"
    assert_selector ".bg-gray-200.rounded.h-4", minimum: 3
  end
end
