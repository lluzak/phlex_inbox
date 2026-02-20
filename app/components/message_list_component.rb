# frozen_string_literal: true

class MessageListComponent < ApplicationComponent
  include LiveComponent

  subscribes_to :contact
  broadcasts stream: ->(contact) { [contact, :messages] }

  def initialize(messages: nil, folder: "inbox", current_contact: nil, contact: nil, selected_id: nil, active_filters: {}, labels: [], **_extra)
    @contact = current_contact || contact
    @current_contact = @contact
    @folder = folder.to_s
    @selected_id = selected_id
    @active_filters = active_filters || {}
    @labels = labels.presence || Label.all
    @messages = messages || query_messages
  end

  def render_in(view_context, &block)
    if @active_filters.any? && @current_contact
      super
    else
      inner_html = ApplicationComponent.instance_method(:render_in).bind_call(self, view_context, &block)
      if LiveComponent.debug && @contact
        dom_id_val = self.class.dom_id_for(@contact)
        debug_label = "#{self.class.name.underscore.humanize} ##{dom_id_val}"
        %(<div data-live-debug="#{debug_label}" class="live-debug-wrapper">#{inner_html}</div>).html_safe
      else
        inner_html
      end
    end
  end

  class << self
    def dom_id_for(record)
      "message_list_#{record.id}"
    end
  end

  private

  def live_wrapper_options
    return {} unless @active_filters.any? && @current_contact

    {
      strategy: "notify",
      component_name: self.class.name,
      params: { folder: @folder, record_id: @current_contact.id, active_filters: @active_filters }
    }
  end

  def query_messages
    return [] unless @contact

    scope = case @folder
    when "inbox" then @contact.received_messages.inbox
    when "sent" then @contact.sent_messages.sent_box
    when "archive" then @contact.received_messages.archived
    when "trash" then @contact.received_messages.trashed
    else @contact.received_messages.inbox
    end

    scope = scope.includes(:labels, :sender).newest_first
    filters = (@active_filters || {}).stringify_keys
    scope = scope.unread if filters["unread"] == "1"
    scope = scope.starred_messages if filters["starred"] == "1"
    label_ids = Array(filters["label_ids"]).map(&:to_i).select(&:positive?)
    scope = scope.filter_by_labels(label_ids) if label_ids.any?
    scope
  end

  def current_folder_path
    urls = Rails.application.routes.url_helpers
    case @folder
    when "inbox" then urls.root_path
    when "sent" then urls.sent_messages_path
    when "archive" then urls.archive_messages_path
    when "trash" then urls.trash_messages_path
    else urls.root_path
    end
  end
end
