class Label < ApplicationRecord
  has_many :labelings, dependent: :destroy
  has_many :messages, through: :labelings

  validates :name, presence: true, uniqueness: true
  validates :color, presence: true

  def badge_classes
    color_class = LabelBadgeComponent::COLORS.fetch(color, LabelBadgeComponent::COLORS["blue"])
    "inline-flex items-center rounded-full px-1.5 py-0.5 text-xs font-medium #{color_class}"
  end
end
