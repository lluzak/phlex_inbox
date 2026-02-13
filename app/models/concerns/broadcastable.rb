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

      html = render_wrapped_component(config)
      Turbo::StreamsChannel.broadcast_prepend_to(
        *Array(resolve_stream(config[:stream])),
        target: config[:prepend_target],
        html: html
      )
    end
  end

  def broadcast_live_update
    broadcast_configs.each do |config|
      if config[:component_class].respond_to?(:build_data)
        data = config[:component_class].build_data(self)
        LiveComponentChannel.broadcast_data(
          resolve_stream(config[:stream]),
          action: :update,
          data: data
        )
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
      if config[:component_class].respond_to?(:build_data)
        data = { "id" => id, "dom_id" => ActionView::RecordIdentifier.dom_id(self) }
        LiveComponentChannel.broadcast_data(
          resolve_stream(config[:stream]),
          action: :destroy,
          data: data
        )
      else
        Turbo::StreamsChannel.broadcast_remove_to(
          *Array(resolve_stream(config[:stream])),
          target: ActionView::RecordIdentifier.dom_id(self)
        )
      end
    end
  end

  def resolve_stream(stream)
    stream.is_a?(Proc) ? stream.call(self) : stream
  end

  def render_broadcast_component(config)
    component = config[:component].call(self)
    ApplicationController.render(component, layout: false)
  end

  def render_wrapped_component(config)
    inner_html = render_broadcast_component(config)
    dom_id_val = ActionView::RecordIdentifier.dom_id(self)

    if config[:component_class].respond_to?(:template_element_id)
      stream = resolve_stream(config[:stream])
      signed = Turbo::StreamsChannel.signed_stream_name(stream)
      template_id = config[:component_class].template_element_id

      %(<div id="#{dom_id_val}" data-controller="live-renderer" data-live-renderer-template-id-value="#{template_id}" data-live-renderer-stream-value="#{signed}">#{inner_html}</div>)
    else
      %(<div id="#{dom_id_val}">#{inner_html}</div>)
    end
  end
end
