# frozen_string_literal: true

class ComposeModalComponent < ApplicationComponent
  def initialize(contacts:, reply_to: nil)
    @contacts = contacts
    @reply_to = reply_to
  end
end
