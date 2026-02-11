# frozen_string_literal: true

class Components::MessageRow < Components::Base
  include Components::LiveComponent
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::TimeAgoInWords

  subscribes_to :message

  def initialize(message:, selected: false)
    @message = message
    @selected = selected
  end

  def view_template
    link_to(
      helpers.message_path(@message),
      class: row_classes,
      data: { turbo_frame: "message_detail" }
    ) do
      div(class: "flex items-start gap-3 p-3") do
        render Avatar.new(contact: @message.sender, size: :sm)

        div(class: "flex-1 min-w-0") do
          div(class: "flex items-center justify-between") do
            div(class: "flex items-center gap-2 min-w-0") do
              unread_indicator unless @message.read?
              span(class: sender_name_classes) { @message.sender.name }
            end

            div(class: "flex items-center gap-1 shrink-0") do
              star_button
              span(class: "text-xs text-gray-500") do
                plain time_ago_in_words(@message.created_at)
              end
            end
          end

          div(class: "flex items-center gap-1.5 min-w-0") do
            p(class: subject_classes) { @message.subject }
            label_badges
          end

          p(class: "text-sm text-gray-500 truncate") do
            plain @message.preview(80)
          end
        end
      end
    end
  end

  private

  attr_reader :message

  def row_classes
    base = "block border-b border-gray-100 hover:bg-gray-50 transition-colors"
    if @selected
      "#{base} bg-blue-50"
    elsif !@message.read?
      "#{base} bg-white"
    else
      "#{base} bg-white"
    end
  end

  def sender_name_classes
    if @message.read?
      "text-sm font-medium text-gray-900 truncate"
    else
      "text-sm font-bold text-gray-900 truncate"
    end
  end

  def subject_classes
    if @message.read?
      "text-sm text-gray-700 truncate"
    else
      "text-sm font-semibold text-gray-900 truncate"
    end
  end

  def label_badges
    @message.labels.each do |label|
      render LabelBadge.new(label: label)
    end
  end

  def unread_indicator
    span(class: "inline-block w-2 h-2 bg-blue-600 rounded-full shrink-0")
  end

  def star_button
    button(
      type: "button",
      class: "p-0.5",
      data: {
        controller: "star",
        star_url_value: helpers.toggle_star_message_path(@message),
        action: "click->star#toggle"
      }
    ) do
      if @message.starred?
        starred_icon
      else
        unstarred_icon
      end
    end
  end

  def starred_icon
    svg(
      xmlns: "http://www.w3.org/2000/svg",
      viewbox: "0 0 24 24",
      fill: "currentColor",
      class: "w-4 h-4 text-yellow-400"
    ) do |s|
      s.path(
        fill_rule: "evenodd",
        d: "M10.788 3.21c.448-1.077 1.976-1.077 2.424 0l2.082 5.007 5.404.433c1.164" \
           ".093 1.636 1.545.749 2.305l-4.117 3.527 1.257 5.273c.271 1.136-.964 " \
           "2.033-1.96 1.425L12 18.354 7.373 21.18c-.996.608-2.231-.29-1.96-1.425l" \
           "1.257-5.273-4.117-3.527c-.887-.76-.415-2.212.749-2.305l5.404-.433 2.082-5.006z",
        clip_rule: "evenodd"
      )
    end
  end

  def unstarred_icon
    svg(
      xmlns: "http://www.w3.org/2000/svg",
      fill: "none",
      viewbox: "0 0 24 24",
      stroke_width: "1.5",
      stroke: "currentColor",
      class: "w-4 h-4 text-gray-300 hover:text-yellow-400"
    ) do |s|
      s.path(
        stroke_linecap: "round",
        stroke_linejoin: "round",
        d: "M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l" \
           "5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l" \
           "1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 " \
           "20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602" \
           "a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z"
      )
    end
  end
end
