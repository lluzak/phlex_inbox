# frozen_string_literal: true

class MessageListComponent < ApplicationComponent
  def initialize(messages:, folder:, current_contact: nil, selected_id: nil)
    @messages = messages
    @folder = folder
    @current_contact = current_contact
    @selected_id = selected_id
  end

  private

  def signed_stream_name
    return unless @current_contact

    Turbo::StreamsChannel.signed_stream_name([ @current_contact, :messages ])
  end
end
