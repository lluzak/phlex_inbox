# frozen_string_literal: true

class Components::LabelBadge < Components::Base
  COLORS = {
    "blue" => "bg-blue-100 text-blue-700",
    "green" => "bg-green-100 text-green-700",
    "red" => "bg-red-100 text-red-700",
    "yellow" => "bg-yellow-100 text-yellow-700",
    "purple" => "bg-purple-100 text-purple-700",
    "indigo" => "bg-indigo-100 text-indigo-700"
  }.freeze

  def initialize(label:)
    @label = label
  end

  def view_template
    span(class: badge_classes) { @label.name }
  end

  private

  def badge_classes
    color_classes = COLORS.fetch(@label.color, COLORS["blue"])
    "inline-flex items-center rounded-full px-1.5 py-0.5 text-xs font-medium #{color_classes}"
  end
end
