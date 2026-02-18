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

  def request_update(data)
    component_class = data["component"].constantize
    model_class = component_class.live_model_attr.to_s.classify.constantize
    record = model_class.find_by(id: data["record_id"])
    return unless record

    if matches_filters?(record, data["params"] || {})
      transmit({ "action" => "update", "data" => component_class.build_data(record) })
    else
      transmit({ "action" => "remove", "dom_id" => data["dom_id"] })
    end
  end

  private

  def matches_filters?(record, params)
    scope = record.class.where(id: record.id)
    scope = scope.unread if params["unread"] == "1"
    scope = scope.starred_messages if params["starred"] == "1"

    label_ids = params["label_ids"]
    scope = scope.filter_by_labels(label_ids) if label_ids.present?

    scope.exists?
  end

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
