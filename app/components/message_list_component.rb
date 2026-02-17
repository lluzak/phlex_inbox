# frozen_string_literal: true

class MessageListComponent < ApplicationComponent
  def initialize(messages:, folder:, current_contact: nil, selected_id: nil, active_filters: {})
    @messages = messages
    @folder = folder
    @current_contact = current_contact
    @selected_id = selected_id
    @active_filters = active_filters
  end

  private

  def current_folder_path
    case @folder
    when "inbox" then helpers.root_path
    when "sent" then helpers.sent_messages_path
    when "archive" then helpers.archive_messages_path
    when "trash" then helpers.trash_messages_path
    else helpers.root_path
    end
  end

  def signed_stream_name
    return unless @current_contact

    Turbo::StreamsChannel.signed_stream_name([ @current_contact, :messages ])
  end

  def client_state_for(message)
    MessageRowComponent.client_state_values(selected: message.id == @selected_id).to_json
  end

  def initial_data_for(message)
    MessageRowComponent.build_data(message, selected: message.id == @selected_id).to_json
  end
end
