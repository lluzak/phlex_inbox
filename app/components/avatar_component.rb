# frozen_string_literal: true

class AvatarComponent < ApplicationComponent
  SIZES = {
    sm: "w-8 h-8 text-xs",
    md: "w-10 h-10 text-sm",
    lg: "w-12 h-12 text-base"
  }.freeze

  COLORS = %w[
    bg-red-500 bg-orange-500 bg-amber-500 bg-yellow-500
    bg-lime-500 bg-green-500 bg-emerald-500 bg-teal-500
    bg-cyan-500 bg-sky-500 bg-blue-500 bg-indigo-500
    bg-violet-500 bg-purple-500 bg-fuchsia-500 bg-pink-500
  ].freeze

  def initialize(contact:, size: :md)
    @contact = contact
    @size = size
  end

  private

  def color_for(name)
    COLORS[name.sum % COLORS.length]
  end
end
