# frozen_string_literal: true

module Broadcastable
  extend ActiveSupport::Concern

  included do
    class_attribute :broadcast_configs, instance_writer: false, default: []
  end

  class_methods do
    def broadcasts_component(component_class, stream:, component: nil, prepend_target: nil)
      config = {
        component_class: component_class,
        stream: stream,
        component: component || ->(record) { component_class.new(model_name.element.to_sym => record) },
        prepend_target: prepend_target
      }

      self.broadcast_configs = broadcast_configs + [ config ]

      after_create_commit :broadcast_live_create
      after_update_commit :broadcast_live_update
      after_destroy_commit :broadcast_live_destroy
    end
  end

  private

  def broadcast_live_create
    broadcast_configs.each do |config|
      next unless config[:prepend_target]

      html = render_broadcast_component(config)
      Turbo::StreamsChannel.broadcast_prepend_to(
        *Array(resolve_stream(config[:stream])),
        target: config[:prepend_target],
        html: html
      )
    end
  end

  def broadcast_live_update
    broadcast_configs.each do |config|
      html = render_broadcast_component(config)
      Turbo::StreamsChannel.broadcast_replace_to(
        *Array(resolve_stream(config[:stream])),
        target: ActionView::RecordIdentifier.dom_id(self),
        html: html
      )
    end
  end

  def broadcast_live_destroy
    broadcast_configs.each do |config|
      Turbo::StreamsChannel.broadcast_remove_to(
        *Array(resolve_stream(config[:stream])),
        target: ActionView::RecordIdentifier.dom_id(self)
      )
    end
  end

  def resolve_stream(stream)
    stream.is_a?(Proc) ? stream.call(self) : stream
  end

  def render_broadcast_component(config)
    component = config[:component].call(self)
    ApplicationController.render(component, layout: false)
  end
end
