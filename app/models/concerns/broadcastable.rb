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

      if compiled_template_for?(config)
        broadcast_data_create(config)
      else
        html = render_broadcast_component(config)
        Turbo::StreamsChannel.broadcast_prepend_to(
          *Array(resolve_stream(config[:stream])),
          target: config[:prepend_target],
          html: html
        )
      end
    end
  end

  def broadcast_live_update
    broadcast_configs.each do |config|
      if compiled_template_for?(config)
        broadcast_data_update(config)
      else
        html = render_broadcast_component(config)
        Turbo::StreamsChannel.broadcast_replace_to(
          *Array(resolve_stream(config[:stream])),
          target: ActionView::RecordIdentifier.dom_id(self),
          html: html
        )
      end
    end
  end

  def broadcast_live_destroy
    broadcast_configs.each do |config|
      if compiled_template_for?(config)
        broadcast_data_destroy(config)
      else
        Turbo::StreamsChannel.broadcast_remove_to(
          *Array(resolve_stream(config[:stream])),
          target: ActionView::RecordIdentifier.dom_id(self)
        )
      end
    end
  end

  def broadcast_data_create(config)
    serializer = config[:component_class].data_serializer
    data = serializer.serialize(self)
    stream = Array(resolve_stream(config[:stream]))

    LiveComponentChannel.broadcast_data(stream, action: "create", data: data)
  end

  def broadcast_data_update(config)
    serializer = config[:component_class].data_serializer
    data = serializer.serialize_changes(self) || serializer.serialize(self)
    stream = Array(resolve_stream(config[:stream]))

    LiveComponentChannel.broadcast_data(stream, action: "update", data: data)
  end

  def broadcast_data_destroy(config)
    stream = Array(resolve_stream(config[:stream]))
    LiveComponentChannel.broadcast_data(stream, action: "destroy", data: { "id" => id })
  end

  def compiled_template_for?(config)
    config[:component_class].respond_to?(:compiled_template_js) &&
      config[:component_class].compiled_template_js
  end

  def resolve_stream(stream)
    stream.is_a?(Proc) ? stream.call(self) : stream
  end

  def render_broadcast_component(config)
    component = config[:component].call(self)
    ApplicationController.render(component, layout: false)
  end
end
