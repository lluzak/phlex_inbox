# frozen_string_literal: true

class MessageRowComponent < ApplicationComponent
  include LiveComponent

  subscribes_to :message

  def initialize(message:, selected: false)
    @message = message
    @selected = selected
  end

  private

  def avatar_color(sender)
    AvatarComponent::COLORS[sender.name.sum % AvatarComponent::COLORS.length]
  end

  def label_color_classes(label)
    LabelBadgeComponent::COLORS.fetch(label.color, LabelBadgeComponent::COLORS["blue"])
  end
end
