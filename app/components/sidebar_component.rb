# frozen_string_literal: true

class SidebarComponent < ApplicationComponent
  FOLDERS = [
    {
      key: :inbox,
      label: "Inbox",
      scope: :inbox,
      icon: "M2.25 13.5h3.86a2.25 2.25 0 012.012 1.244l.256.512a2.25 2.25 0 " \
            "002.013 1.244h3.218a2.25 2.25 0 002.013-1.244l.256-.512a2.25 2.25 " \
            "0 012.013-1.244h3.859m-19.5.338V18a2.25 2.25 0 002.25 2.25h15A2.25 " \
            "2.25 0 0021.75 18v-4.162c0-.224-.034-.447-.1-.661L19.24 5.338a2.25 " \
            "2.25 0 00-2.15-1.588H6.911a2.25 2.25 0 00-2.15 1.588L2.35 " \
            "13.177a2.25 2.25 0 00-.1.661z"
    },
    {
      key: :sent,
      label: "Sent",
      scope: :sent_box,
      icon: "M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 " \
            "013.27 20.876L5.999 12zm0 0h7.5"
    },
    {
      key: :archive,
      label: "Archive",
      scope: :archived,
      icon: "M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 " \
            "2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 " \
            "0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c" \
            "-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z"
    },
    {
      key: :trash,
      label: "Trash",
      scope: :trashed,
      icon: "M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 " \
            "1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 " \
            "2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 " \
            "0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 " \
            "1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-" \
            ".91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 " \
            "1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"
    }
  ].freeze

  def initialize(current_folder:, current_contact:)
    @current_folder = current_folder
    @current_contact = current_contact
  end

  private

  def folder_path(key)
    case key
    when :inbox then helpers.root_path
    when :sent then helpers.sent_messages_path
    when :archive then helpers.archive_messages_path
    when :trash then helpers.trash_messages_path
    end
  end

  def folder_link_classes(active)
    base = "flex items-center px-3 py-2 text-sm font-medium rounded-md w-full"
    if active
      "#{base} bg-blue-50 text-blue-700"
    else
      "#{base} text-gray-700 hover:bg-gray-50 hover:text-gray-900"
    end
  end

  def unread_count_for(scope)
    @current_contact.received_messages.send(scope).unread.count
  end
end
