# frozen_string_literal: true

class Views::Messages::Show < Views::Base
  include Phlex::Rails::Helpers::TurboFrameTag

  def initialize(message:)
    @message = message
  end

  def view_template
    turbo_frame_tag("message_detail") do
      render Components::MessageDetail.new(message: @message)
    end
  end
end
