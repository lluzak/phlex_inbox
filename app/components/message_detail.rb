# frozen_string_literal: true

class Components::MessageDetail < Components::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::TimeAgoInWords

  def initialize(message:)
    @message = message
  end

  def view_template
    div(class: "h-full flex flex-col") do
      action_bar
      message_header
      message_body
      reply_section
    end
  end

  private

  def action_bar
    div(class: "flex items-center gap-2 px-6 py-3 border-b border-gray-200") do
      action_button("Archive", helpers.move_message_path(@message, label: "archive"), archive_icon)
      action_button("Trash", helpers.move_message_path(@message, label: "trash"), trash_icon)
      action_button("Mark unread", helpers.toggle_read_message_path(@message), unread_icon)
    end
  end

  def action_button(label, path, icon)
    button_to(
      path,
      method: :patch,
      class: "inline-flex items-center gap-1.5 px-3 py-1.5 text-sm text-gray-600 " \
             "hover:text-gray-900 hover:bg-gray-100 rounded-md",
      data: { turbo_stream: true }
    ) do
      icon
      plain label
    end
  end

  def message_header
    div(class: "px-6 py-4 border-b border-gray-200") do
      h2(class: "text-xl font-semibold text-gray-900 mb-4") { @message.subject }

      div(class: "flex items-start gap-4") do
        render Avatar.new(contact: @message.sender, size: :lg)

        div(class: "flex-1") do
          div(class: "flex items-center justify-between") do
            div do
              span(class: "font-semibold text-gray-900") { @message.sender.name }
              span(class: "text-sm text-gray-500 ml-2") do
                plain "<#{@message.sender.email}>"
              end
            end
            span(class: "text-sm text-gray-500") do
              plain "#{time_ago_in_words(@message.created_at)} ago"
            end
          end

          p(class: "text-sm text-gray-500 mt-0.5") do
            plain "To: #{@message.recipient.name}"
          end
        end
      end
    end
  end

  def message_body
    div(class: "flex-1 px-6 py-4 overflow-y-auto") do
      div(class: "prose max-w-none") do
        p(style: "white-space: pre-wrap;", class: "text-gray-800") { @message.body }
      end
    end
  end

  def reply_section
    div(class: "px-6 py-4 border-t border-gray-200") do
      render Button.new(
        variant: :primary,
        data: {
          action: "click->compose#reply",
          compose_message_id_param: @message.id,
          compose_sender_name_param: @message.sender.name,
          compose_subject_param: @message.subject
        }
      ) do
        reply_icon
        plain " Reply"
      end
    end
  end

  def archive_icon
    svg(
      xmlns: "http://www.w3.org/2000/svg",
      fill: "none",
      viewbox: "0 0 24 24",
      stroke_width: "1.5",
      stroke: "currentColor",
      class: "w-4 h-4"
    ) do |s|
      s.path(
        stroke_linecap: "round",
        stroke_linejoin: "round",
        d: "M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 " \
           "2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 " \
           "0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c" \
           "-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z"
      )
    end
  end

  def trash_icon
    svg(
      xmlns: "http://www.w3.org/2000/svg",
      fill: "none",
      viewbox: "0 0 24 24",
      stroke_width: "1.5",
      stroke: "currentColor",
      class: "w-4 h-4"
    ) do |s|
      s.path(
        stroke_linecap: "round",
        stroke_linejoin: "round",
        d: "M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 " \
           "1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 " \
           "2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 " \
           "0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 " \
           "1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-" \
           ".91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 " \
           "1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0"
      )
    end
  end

  def unread_icon
    svg(
      xmlns: "http://www.w3.org/2000/svg",
      fill: "none",
      viewbox: "0 0 24 24",
      stroke_width: "1.5",
      stroke: "currentColor",
      class: "w-4 h-4"
    ) do |s|
      s.path(
        stroke_linecap: "round",
        stroke_linejoin: "round",
        d: "M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 " \
           "01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 " \
           "2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 " \
           "4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75"
      )
    end
  end

  def reply_icon
    svg(
      xmlns: "http://www.w3.org/2000/svg",
      fill: "none",
      viewbox: "0 0 24 24",
      stroke_width: "1.5",
      stroke: "currentColor",
      class: "w-4 h-4 inline"
    ) do |s|
      s.path(
        stroke_linecap: "round",
        stroke_linejoin: "round",
        d: "M9 15L3 9m0 0l6-6M3 9h12a6 6 0 010 12h-3"
      )
    end
  end
end
