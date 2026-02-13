# frozen_string_literal: true

class MessageListComponent < ApplicationComponent
  def initialize(messages:, folder:, current_contact: nil, selected_id: nil)
    @messages = messages
    @folder = folder
    @current_contact = current_contact
    @selected_id = selected_id
  end

  private

  def live_list_data_attrs
    attrs = {}
    return attrs unless @current_contact

    stream = Turbo::StreamsChannel.signed_stream_name([@current_contact, :messages])
    attrs[:controller] = "live-list"
    attrs[:live_list_stream_value] = stream
    attrs
  end
end
