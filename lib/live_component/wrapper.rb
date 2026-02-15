# frozen_string_literal: true

module LiveComponent
  module Wrapper
    module_function

    def wrap(component_class, record, inner_html, stream: nil)
      dom_id_val = component_class.dom_id_for(record)

      attrs = [
        %(id="#{dom_id_val}"),
        %(data-controller="live-renderer"),
        %(data-live-renderer-template-value="#{component_class.encoded_template}")
      ]

      if stream
        signed = Turbo::StreamsChannel.signed_stream_name(stream)
        attrs << %(data-live-renderer-stream-value="#{signed}")
      end

      if component_class._live_actions.any?
        attrs << %(data-live-renderer-action-url-value="#{Rails.application.routes.url_helpers.live_component_actions_path}")
        attrs << %(data-live-renderer-action-token-value="#{component_class.live_action_token(record)}")
      end

      %(<div #{attrs.join(" ")}>#{inner_html}</div>).html_safe
    end

    def find_stream_for(component_class, record)
      config = component_class._broadcast_config
      return nil unless config

      stream = config[:stream]
      stream.is_a?(Proc) ? stream.call(record) : stream
    end
  end
end
