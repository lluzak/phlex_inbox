# frozen_string_literal: true

class EmptyStateComponent < ApplicationComponent
  def initialize(title:, description:)
    @title = title
    @description = description
  end
end
