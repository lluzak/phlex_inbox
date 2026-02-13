# frozen_string_literal: true

class MessageDetailComponent < ApplicationComponent
  def initialize(message:)
    @message = message
  end
end
