# frozen_string_literal: true

class Views::Messages::Index < Views::Base
  def initialize(messages:, folder:, current_contact:)
    @messages = messages
    @folder = folder
    @current_contact = current_contact
  end

  def view_template
    render Components::InboxLayout.new(
      sidebar: Components::Sidebar.new(current_folder: @folder, current_contact: @current_contact),
      message_list: Components::MessageList.new(messages: @messages, folder: @folder)
    )

    contacts = Contact.where.not(id: @current_contact.id).order(:name)
    render Components::ComposeModal.new(contacts: contacts)
  end
end
