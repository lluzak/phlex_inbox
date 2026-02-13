# frozen_string_literal: true

class LiveComponentChannel < ApplicationCable::Channel
  def subscribed
    stream_name = verified_stream_name
    if stream_name
      stream_from stream_name
    else
      reject
    end
  end

  def unsubscribed
    stop_all_streams
  end

  private

  def verified_stream_name
    Turbo::StreamsChannel.verified_stream_name(params[:signed_stream_name])
  rescue
    nil
  end

  class << self
    def broadcast_data(streamables, action:, data:)
      # Sign then verify to get the same unsigned stream name that stream_from uses
      signed = Turbo::StreamsChannel.signed_stream_name(streamables)
      stream_name = Turbo::StreamsChannel.verified_stream_name(signed)
      ActionCable.server.broadcast(stream_name, { action: action, data: data })
    end
  end
end
