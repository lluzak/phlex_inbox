# frozen_string_literal: true

class PresenceChannel < ApplicationCable::Channel
  def subscribed
    @message_id = params[:message_id].to_i
    @session_id = params[:session_id]
    @role = params[:role] || "viewer"

    if @message_id.positive? && @session_id.present?
      stream_from stream_name
      if viewer?
        viewers = PresenceTracker.join(@message_id, @session_id)
        broadcast_viewers(viewers)
        broadcast_global_viewers(PresenceTracker.global_viewing(@session_id, @message_id))
      end
    else
      reject
    end
  end

  def unsubscribed
    return unless @message_id && @session_id && viewer?

    viewers = PresenceTracker.leave(@message_id, @session_id)
    broadcast_viewers(viewers)
    broadcast_global_viewers(PresenceTracker.global_viewing(@session_id, nil))
  end

  def heartbeat
    return unless @message_id && @session_id && viewer?

    viewers = PresenceTracker.touch(@message_id, @session_id)
    broadcast_viewers(viewers)
  end

  def typing(data)
    return unless @message_id && @session_id && viewer?

    status = data["status"] == "typing" ? "typing" : "viewing"
    viewers = PresenceTracker.update_status(@message_id, @session_id, status)
    broadcast_viewers(viewers) if viewers
  end

  private

  def stream_name
    "presence:message_#{@message_id}"
  end

  def viewer?
    @role == "viewer"
  end

  def broadcast_viewers(viewers)
    ActionCable.server.broadcast(stream_name, { type: "viewers", viewers: viewers })
  end

  def broadcast_global_viewers(viewers)
    return unless viewers

    ActionCable.server.broadcast("presence:global", { type: "global_viewers", viewers: viewers })
  end
end
