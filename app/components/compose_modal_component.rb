# frozen_string_literal: true

class ComposeModalComponent < ApplicationComponent
  def initialize(contacts:)
    @contacts = contacts
  end
end
