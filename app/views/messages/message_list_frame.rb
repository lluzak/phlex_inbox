# frozen_string_literal: true

class Views::Messages::MessageListFrame < Views::Base
  include Phlex::Rails::Helpers::TurboFrameTag

  def initialize(messages:, folder:)
    @messages = messages
    @folder = folder
  end

  def view_template
    turbo_frame_tag("message_list") do
      render Components::MessageList.new(messages: @messages, folder: @folder)
    end
  end
end
