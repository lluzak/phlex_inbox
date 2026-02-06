# frozen_string_literal: true

class Components::ComposeModal < Components::Base
  include Phlex::Rails::Helpers::FormWith

  def initialize(contacts:, reply_to: nil)
    @contacts = contacts
    @reply_to = reply_to
  end

  def view_template
    div(
      data: {
        controller: "compose",
        compose_open_class: "flex",
        compose_closed_class: "hidden"
      },
      class: "hidden"
    ) do
      overlay
      modal_panel
    end
  end

  private

  def overlay
    div(
      class: "fixed inset-0 bg-gray-500 bg-opacity-75 z-40",
      data: { action: "click->compose#close" }
    )
  end

  def modal_panel
    div(class: "fixed inset-0 z-50 flex items-center justify-center p-4") do
      div(class: "bg-white rounded-lg shadow-xl w-full max-w-lg") do
        modal_header
        modal_form
      end
    end
  end

  def modal_header
    div(class: "flex items-center justify-between px-6 py-4 border-b border-gray-200") do
      h3(class: "text-lg font-semibold text-gray-900") do
        plain @reply_to ? "Reply" : "New Message"
      end
      render Button.new(
        variant: :icon,
        data: { action: "click->compose#close" }
      ) do
        close_icon
      end
    end
  end

  def modal_form
    form_with(url: helpers.messages_path, class: "p-6 space-y-4") do |f|
      if @reply_to
        reply_fields(f)
      else
        recipient_select(f)
      end

      subject_field(f)
      body_field(f)
      form_actions(f)
    end
  end

  def reply_fields(form)
    form.hidden_field(:replied_to_id, value: @reply_to.id)
    form.hidden_field(:recipient_id, value: @reply_to.sender_id)

    div(class: "text-sm text-gray-600") do
      plain "To: #{@reply_to.sender.name}"
    end
  end

  def recipient_select(form)
    div do
      form.label(:recipient_id, "To", class: "block text-sm font-medium text-gray-700 mb-1")
      form.select(
        :recipient_id,
        @contacts.map { |c| [c.name, c.id] },
        { prompt: "Select recipient..." },
        class: "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm " \
               "ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset " \
               "focus:ring-blue-600 sm:text-sm sm:leading-6"
      )
    end
  end

  def subject_field(form)
    div do
      form.label(:subject, "Subject", class: "block text-sm font-medium text-gray-700 mb-1")
      form.text_field(
        :subject,
        value: @reply_to ? "Re: #{@reply_to.subject}" : "",
        class: "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm " \
               "ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 " \
               "focus:ring-2 focus:ring-inset focus:ring-blue-600 sm:text-sm sm:leading-6"
      )
    end
  end

  def body_field(form)
    div do
      form.label(:body, "Message", class: "block text-sm font-medium text-gray-700 mb-1")
      form.text_area(
        :body,
        rows: 6,
        class: "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm " \
               "ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 " \
               "focus:ring-2 focus:ring-inset focus:ring-blue-600 sm:text-sm sm:leading-6"
      )
    end
  end

  def form_actions(form)
    div(class: "flex items-center justify-end gap-3 pt-2") do
      render Button.new(
        variant: :ghost,
        type: "button",
        data: { action: "click->compose#close" }
      ) do
        plain "Cancel"
      end

      form.submit(
        "Send",
        class: "inline-flex items-center px-4 py-2 border border-transparent text-sm " \
               "font-medium rounded-md shadow-sm text-white bg-blue-600 " \
               "hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 " \
               "focus:ring-blue-500 cursor-pointer"
      )
    end
  end

  def close_icon
    svg(
      xmlns: "http://www.w3.org/2000/svg",
      fill: "none",
      viewbox: "0 0 24 24",
      stroke_width: "1.5",
      stroke: "currentColor",
      class: "w-5 h-5"
    ) do |s|
      s.path(
        stroke_linecap: "round",
        stroke_linejoin: "round",
        d: "M6 18L18 6M6 6l12 12"
      )
    end
  end
end
