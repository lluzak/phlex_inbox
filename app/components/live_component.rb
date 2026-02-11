# frozen_string_literal: true

module Components::LiveComponent
  extend ActiveSupport::Concern

  included do
    include Phlex::Rails::Helpers::DOMID
  end

  class_methods do
    attr_reader :live_model_attr

    def subscribes_to(attr_name)
      @live_model_attr = attr_name
    end
  end

  def live_model
    send(self.class.live_model_attr)
  end

  def around_template(&block)
    div(id: dom_id(live_model), &block)
  end
end
