# frozen_string_literal: true

class MessageRowComponent < ApplicationComponent
  include LiveComponent

  subscribes_to :message
  broadcasts stream: ->(message) { [message.recipient, :messages] },
             prepend_target: "message_items"
  live_action :toggle_star

  def initialize(message:, selected: false)
    @message = message
    @selected = selected
  end

  private

  def toggle_star
    @message.toggle_starred!
  end

  def avatar_color(sender)
    AvatarComponent::COLORS[sender.name.sum % AvatarComponent::COLORS.length]
  end

  def label_color_classes(label)
    LabelBadgeComponent::COLORS.fetch(label.color, LabelBadgeComponent::COLORS["blue"])
  end
end
