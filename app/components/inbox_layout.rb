# frozen_string_literal: true

class Components::InboxLayout < Components::Base
  include Phlex::Rails::Helpers::TurboFrameTag
  include Phlex::Rails::Helpers::TurboStreamFrom

  def initialize(sidebar:, message_list:, message_detail: nil, current_contact: nil)
    @sidebar = sidebar
    @message_list = message_list
    @message_detail = message_detail
    @current_contact = current_contact
  end

  def view_template
    turbo_stream_from(@current_contact, :messages) if @current_contact

    div(class: "h-screen flex flex-col") do
      header(class: "bg-white border-b border-gray-200 px-6 py-3 flex items-center justify-between shrink-0") do
        h1(class: "text-xl font-bold text-gray-900") { "Phlex Inbox" }
        render SearchBar.new
      end

      div(class: "flex flex-1 overflow-hidden") do
        aside(class: "w-56 bg-white border-r border-gray-200 overflow-y-auto shrink-0") do
          render @sidebar
        end

        div(class: "w-96 border-r border-gray-200 overflow-y-auto bg-white shrink-0") do
          turbo_frame_tag("message_list") do
            render @message_list
          end
        end

        main(class: "flex-1 overflow-y-auto bg-white") do
          turbo_frame_tag("message_detail") do
            if @message_detail
              render @message_detail
            else
              render EmptyState.new(
                title: "Select a message",
                description: "Choose a message from the list to read it."
              )
            end
          end
        end
      end
    end
  end
end
