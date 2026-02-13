# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_contact

    def connect
      self.current_contact = find_verified_contact
    end

    private

    def find_verified_contact
      Contact.find_by!(email: "you@example.com")
    rescue ActiveRecord::RecordNotFound
      reject_unauthorized_connection
    end
  end
end
