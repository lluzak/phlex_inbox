# frozen_string_literal: true

class PresenceTracker
  STALE_THRESHOLD = 30.seconds
  TEAM_MEMBERS = [
    { name: "Alice", initials: "A", color: "bg-purple-500" },
    { name: "Bob", initials: "B", color: "bg-blue-500" },
    { name: "Carol", initials: "C", color: "bg-green-500" },
    { name: "Dana", initials: "D", color: "bg-pink-500" },
    { name: "Eve", initials: "E", color: "bg-orange-500" },
    { name: "Frank", initials: "F", color: "bg-teal-500" }
  ].freeze

  class << self
    def store
      @store ||= Concurrent::Map.new
    end

    def join(message_id, session_id)
      sweep!(message_id)
      viewers = store.compute_if_absent(message_id) { Concurrent::Map.new }
      member = member_for(session_id)
      viewers[session_id] = member.merge(status: "viewing", last_seen: Time.current)
      viewers_for(message_id)
    end

    def leave(message_id, session_id)
      viewers = store[message_id]
      return [] unless viewers

      viewers.delete(session_id)
      store.delete(message_id) if viewers.empty?
      viewers_for(message_id)
    end

    def touch(message_id, session_id)
      sweep!(message_id)
      viewers = store[message_id]
      return [] unless viewers

      entry = viewers[session_id]
      return viewers_for(message_id) unless entry

      viewers[session_id] = entry.merge(last_seen: Time.current)
      viewers_for(message_id)
    end

    def update_status(message_id, session_id, status)
      viewers = store[message_id]
      return unless viewers

      entry = viewers[session_id]
      return unless entry

      viewers[session_id] = entry.merge(status: status, last_seen: Time.current)
      viewers_for(message_id)
    end

    def viewers_for(message_id)
      viewers = store[message_id]
      return [] unless viewers

      viewers.each_pair.map do |session_id, data|
        { session_id: session_id, name: data[:name], initials: data[:initials], color: data[:color],
          status: data[:status] || "viewing" }
      end
    end

    def sweep!(message_id)
      viewers = store[message_id]
      return unless viewers

      cutoff = STALE_THRESHOLD.ago
      viewers.each_pair do |session_id, data|
        viewers.delete(session_id) if data[:last_seen] < cutoff
      end
      store.delete(message_id) if viewers.empty?
    end

    def global_join(session_id)
      member = member_for(session_id).merge(last_seen: Time.current, viewing_message_id: nil)
      global_store.compute_if_absent(session_id) { member }
      global_store[session_id] = global_store[session_id].merge(last_seen: Time.current)
      global_viewers
    end

    def global_leave(session_id)
      global_store.delete(session_id)
      global_viewers
    end

    def global_touch(session_id)
      global_sweep!
      entry = global_store[session_id]
      return global_viewers unless entry

      global_store[session_id] = entry.merge(last_seen: Time.current)
      global_viewers
    end

    def global_viewing(session_id, message_id)
      entry = global_store[session_id]
      return unless entry

      global_store[session_id] = entry.merge(viewing_message_id: message_id)
      global_viewers
    end

    def global_viewers
      global_sweep!
      global_store.each_pair.map do |session_id, data|
        {
          session_id: session_id, name: data[:name], initials: data[:initials],
          color: data[:color], viewing_message_id: data[:viewing_message_id]
        }
      end
    end

    def reset!
      @store = Concurrent::Map.new
      @global_store = Concurrent::Map.new
    end

    private

    def global_store
      @global_store ||= Concurrent::Map.new
    end

    def global_sweep!
      cutoff = STALE_THRESHOLD.ago
      global_store.each_pair do |session_id, data|
        global_store.delete(session_id) if data[:last_seen] < cutoff
      end
    end

    def member_for(session_id)
      index = session_id.hash.abs % TEAM_MEMBERS.size
      TEAM_MEMBERS[index]
    end
  end
end
