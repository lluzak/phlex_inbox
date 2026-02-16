# frozen_string_literal: true

class AvatarComponent < ApplicationComponent
  include LiveComponent

  SIZES = {
    sm: "w-8 h-8 text-xs",
    md: "w-10 h-10 text-sm",
    lg: "w-12 h-12 text-base"
  }.freeze

  def initialize(contact:, size: :md)
    @contact = contact
    @size = size
  end
end
