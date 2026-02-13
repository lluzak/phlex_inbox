# frozen_string_literal: true

class BadgeComponent < ApplicationComponent
  def initialize(count:)
    @count = count
  end

  def render?
    @count.positive?
  end
end
