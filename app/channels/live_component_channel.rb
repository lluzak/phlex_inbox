# frozen_string_literal: true

class LiveComponentChannel < ApplicationCable::Channel
  mattr_accessor :compress, default: false

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
      signed = Turbo::StreamsChannel.signed_stream_name(streamables)
      stream_name = Turbo::StreamsChannel.verified_stream_name(signed)

      payload = { action: action, data: data }

      if compress
        json = ActiveSupport::JSON.encode(payload)
        ActionCable.server.broadcast(stream_name, { z: Base64.strict_encode64(ActiveSupport::Gzip.compress(json)) })
      else
        ActionCable.server.broadcast(stream_name, payload)
      end
    end
  end
end
