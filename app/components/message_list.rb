# frozen_string_literal: true

class Components::MessageList < Components::Base
  def initialize(messages:, folder:, selected_id: nil)
    @messages = messages
    @folder = folder
    @selected_id = selected_id
  end

  def view_template
    div do
      header(class: "px-4 py-3 border-b border-gray-200") do
        div(class: "flex items-center justify-between") do
          h2(class: "text-lg font-semibold text-gray-900 capitalize") { @folder.to_s }
          span(class: "text-sm text-gray-500") do
            plain "#{@messages.size} messages"
          end
        end
      end

      if @messages.any?
        div do
          @messages.each do |message|
            render MessageRow.new(
              message: message,
              selected: message.id == @selected_id
            )
          end
        end
      else
        render EmptyState.new(
          title: "No messages",
          description: "This folder is empty."
        )
      end
    end
  end
end
