# frozen_string_literal: true

class GlobalPresenceChannel < ApplicationCable::Channel
  def subscribed
    @session_id = params[:session_id]

    if @session_id.present?
      stream_from "presence:global"
      viewers = PresenceTracker.global_join(@session_id)
      broadcast_viewers(viewers)
    else
      reject
    end
  end

  def unsubscribed
    return unless @session_id

    viewers = PresenceTracker.global_leave(@session_id)
    broadcast_viewers(viewers)
  end

  def heartbeat
    return unless @session_id

    viewers = PresenceTracker.global_touch(@session_id)
    broadcast_viewers(viewers)
  end

  private

  def broadcast_viewers(viewers)
    ActionCable.server.broadcast("presence:global", { type: "global_viewers", viewers: viewers })
  end
end
