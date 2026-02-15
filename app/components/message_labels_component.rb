# frozen_string_literal: true

class MessageLabelsComponent < ApplicationComponent
  include LiveComponent

  subscribes_to :message
  broadcasts stream: ->(message) { [message.recipient, :messages] }

  def self.dom_id_prefix
    :labels
  end

  live_action :add_label, params: [ :label_id ]
  live_action :remove_label, params: [ :label_id ]

  def initialize(message:)
    @message = message
    @labels = Label.order(:name)
  end

  private

  def add_label(label_id:)
    @message.labels << Label.find(label_id) unless @message.label_ids.include?(label_id.to_i)
  end

  def remove_label(label_id:)
    @message.labelings.find_by(label_id: label_id)&.destroy
  end

  def label_action(message, label)
    message.label_ids.include?(label.id) ? "remove_label" : "add_label"
  end

  def label_css(message, label)
    if message.label_ids.include?(label.id)
      LabelBadgeComponent::COLORS.fetch(label.color, LabelBadgeComponent::COLORS["blue"])
    else
      "bg-gray-100 text-gray-500 hover:bg-gray-200"
    end
  end

  def label_text(message, label)
    if message.label_ids.include?(label.id)
      "#{label.name} \u00D7"
    else
      label.name
    end
  end
end
