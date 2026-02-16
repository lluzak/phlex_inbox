# frozen_string_literal: true

class InboxLayoutComponent < ApplicationComponent
  def initialize(sidebar:, message_list:, message: nil, current_contact: nil)
    @sidebar = sidebar
    @message_list = message_list
    @message = message
    @current_contact = current_contact
  end
end
