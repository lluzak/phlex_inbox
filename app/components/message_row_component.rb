# frozen_string_literal: true

class MessageRowComponent < ApplicationComponent
  include LiveComponent

  subscribes_to :message

  def initialize(message:, selected: false)
    @message = message
    @selected = selected
  end

  private

  def row_classes(message, selected)
    "block border-b border-gray-100 hover:bg-gray-50 transition-colors #{selected ? 'bg-blue-50' : 'bg-white'}"
  end

  def sender_name_classes(message)
    "text-sm #{message.read? ? 'font-medium' : 'font-bold'} text-gray-900 truncate"
  end

  def subject_classes(message)
    "text-sm #{message.read? ? 'text-gray-700' : 'font-semibold text-gray-900'} truncate"
  end

  def avatar_color(sender)
    AvatarComponent::COLORS[sender.name.sum % AvatarComponent::COLORS.length]
  end
end
