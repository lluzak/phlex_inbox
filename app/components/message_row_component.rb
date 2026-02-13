# frozen_string_literal: true

class MessageRowComponent < ApplicationComponent
  include LiveComponent

  subscribes_to :message

  STARRED_ICON = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-4 h-4 text-yellow-400"><path fill-rule="evenodd" d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.007 5.404.433c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.433 2.082-5.006z" clip-rule="evenodd" /></svg>'
  UNSTARRED_ICON = '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-gray-300 hover:text-yellow-400"><path stroke-linecap="round" stroke-linejoin="round" d="M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z" /></svg>'

  LabelData = Data.define(:name, :badge_classes)

  def initialize(message:, selected: false)
    @message = message
    @selected = selected
  end

  def before_render
    assign_data(self.class.build_data(@message, selected: @selected))
  end

  def self.build_data(message, selected: false)
    {
      "id" => message.id,
      "dom_id" => ActionView::RecordIdentifier.dom_id(message),
      "message_path" => url_helpers.message_path(message),
      "toggle_star_path" => url_helpers.toggle_star_message_path(message),
      "row_classes" => "block border-b border-gray-100 hover:bg-gray-50 transition-colors" +
                       (selected ? " bg-blue-50" : " bg-white"),
      "sender_avatar_url" => message.sender_avatar_url,
      "sender_name" => message.sender.name,
      "sender_color" => AvatarComponent::COLORS[message.sender.name.sum % AvatarComponent::COLORS.length],
      "sender_initials" => message.sender.initials,
      "sender_name_classes" => message.read? ? "text-sm font-medium text-gray-900 truncate" : "text-sm font-bold text-gray-900 truncate",
      "subject_classes" => message.read? ? "text-sm text-gray-700 truncate" : "text-sm font-semibold text-gray-900 truncate",
      "read" => message.read?,
      "starred" => message.starred?,
      "star_icon" => message.starred? ? STARRED_ICON : UNSTARRED_ICON,
      "subject" => message.subject,
      "preview" => message.preview,
      "time_ago" => ApplicationController.helpers.time_ago_in_words(message.created_at),
      "labels" => message.labels.map { |l|
        LabelData.new(
          name: l.name,
          badge_classes: "inline-flex items-center rounded-full px-1.5 py-0.5 text-xs font-medium #{LabelBadgeComponent::COLORS.fetch(l.color, LabelBadgeComponent::COLORS['blue'])}"
        )
      }
    }
  end

  def self.url_helpers
    Rails.application.routes.url_helpers
  end

  private

  def assign_data(data)
    data.each do |key, value|
      instance_variable_set(:"@#{key}", value)
    end
  end
end
