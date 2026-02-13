# frozen_string_literal: true

class MessageRowComponent < ApplicationComponent
  include LiveComponent

  subscribes_to :message
  data_fields :subject, :preview, :sender_name, :sender_avatar_url, :created_at
  data_predicates :read, :starred
  data_helpers :message_path, :toggle_star_message_path
  data_iterations labels: [:name, :color, :badge_classes]
  data_derived :sender_color_for, :sender_initials

  STARRED_ICON = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="w-4 h-4 text-yellow-400"><path fill-rule="evenodd" d="M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.007 5.404.433c1.164.093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.433 2.082-5.006z" clip-rule="evenodd" /></svg>'
  UNSTARRED_ICON = '<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-4 h-4 text-gray-300 hover:text-yellow-400"><path stroke-linecap="round" stroke-linejoin="round" d="M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z" /></svg>'

  def initialize(message:, selected: false)
    @message = message
    @selected = selected
  end

  def call
    serializer = self.class.data_serializer
    data = serializer.serialize(@message)
    data["selected"] = @selected

    inner_html = self.class.render_html(data)

    template_js = self.class.compiled_template_js
    wrapper_data = {
      controller: "live-renderer",
      live_renderer_template_value: template_js ? Base64.strict_encode64(template_js) : "",
      live_renderer_data_value: data.to_json,
      live_renderer_stream_value: live_stream_signed_name
    }

    content_tag(:div, inner_html.html_safe, id: dom_id(@message), data: wrapper_data)
  end

  # Pure Ruby string builder — single source of truth for template.
  # Uses string concatenation (not interpolation) for ruby2js compatibility.
  def self.render_html(data)
    selected = data["selected"]
    read = data["read"]
    starred = data["starred"]
    subject = data["subject"]
    preview = data["preview"]
    sender_name = data["sender_name"]
    sender_avatar_url = data["sender_avatar_url"]
    sender_color = data["sender_color_for"]
    sender_init = data["sender_initials"]
    created_at = data["created_at"]
    message_path = data["message_path"]
    toggle_star_path = data["toggle_star_message_path"]
    labels = data["labels"] || []

    row_class = "block border-b border-gray-100 hover:bg-gray-50 transition-colors"
    row_class += selected ? " bg-blue-50" : " bg-white"

    sender_class = read ? "text-sm font-medium text-gray-900 truncate" : "text-sm font-bold text-gray-900 truncate"
    subject_class = read ? "text-sm text-gray-700 truncate" : "text-sm font-semibold text-gray-900 truncate"

    avatar_html = (sender_avatar_url && sender_avatar_url != "") ?
      "<img src=\"" + escapeHtml(sender_avatar_url) + "\" alt=\"" + escapeHtml(sender_name) + "\" class=\"w-8 h-8 text-xs rounded-full object-cover\">" :
      "<div class=\"w-8 h-8 text-xs " + escapeHtml(sender_color) + " rounded-full flex items-center justify-center text-white font-medium\">" + escapeHtml(sender_init) + "</div>"

    unread_html = read ? "" : "<span class=\"inline-block w-2 h-2 bg-blue-600 rounded-full shrink-0\"></span>"

    star_html = starred ? STARRED_ICON : UNSTARRED_ICON

    label_html = labels.map {|label| "<span class=\"" + escapeHtml(label["badge_classes"]) + "\">" + escapeHtml(label["name"]) + "</span>"}.join("")

    return "<a href=\"" + escapeHtml(message_path) + "\" class=\"" + row_class + "\" data-turbo-frame=\"message_detail\">" +
      "<div class=\"flex items-start gap-3 p-3\">" +
        avatar_html +
        "<div class=\"flex-1 min-w-0\">" +
          "<div class=\"flex items-center justify-between\">" +
            "<div class=\"flex items-center gap-2 min-w-0\">" +
              unread_html +
              "<span class=\"" + sender_class + "\">" + escapeHtml(sender_name) + "</span>" +
            "</div>" +
            "<div class=\"flex items-center gap-1 shrink-0\">" +
              "<button type=\"button\" class=\"p-0.5\" data-controller=\"star\" data-star-url-value=\"" + escapeHtml(toggle_star_path) + "\" data-action=\"click->star#toggle\">" +
                star_html +
              "</button>" +
              "<span class=\"text-xs text-gray-500\">" + escapeHtml(created_at) + "</span>" +
            "</div>" +
          "</div>" +
          "<div class=\"flex items-center gap-1.5 min-w-0\">" +
            "<p class=\"" + subject_class + "\">" + escapeHtml(subject) + "</p>" +
            label_html +
          "</div>" +
          "<p class=\"text-sm text-gray-500 truncate\">" + escapeHtml(preview) + "</p>" +
        "</div>" +
      "</div>" +
    "</a>"
  end

  def self.compute_sender_color_for(message)
    colors = AvatarComponent::COLORS
    colors[message.sender.name.sum % colors.length]
  end

  def self.compute_sender_initials(message)
    message.sender.initials
  end

  def self.escapeHtml(text)
    return "" if text.nil?
    text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;").gsub("\"", "&quot;")
  end
end
