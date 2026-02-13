# frozen_string_literal: true

module LiveComponent
  extend ActiveSupport::Concern

  included do
    class_attribute :_live_model_attr, instance_writer: false
    class_attribute :_data_fields, instance_writer: false, default: []
    class_attribute :_data_predicates, instance_writer: false, default: []
    class_attribute :_data_helpers, instance_writer: false, default: []
    class_attribute :_data_iterations, instance_writer: false, default: {}
    class_attribute :_data_derived, instance_writer: false, default: []
  end

  class_methods do
    def subscribes_to(attr_name)
      self._live_model_attr = attr_name
    end

    def live_model_attr
      _live_model_attr
    end

    def data_fields(*fields)
      self._data_fields = _data_fields + fields.map(&:to_sym)
    end

    def data_predicates(*preds)
      self._data_predicates = _data_predicates + preds.map(&:to_sym)
    end

    def data_helpers(*helpers)
      self._data_helpers = _data_helpers + helpers.map(&:to_sym)
    end

    def data_iterations(hash)
      self._data_iterations = _data_iterations.merge(hash)
    end

    def data_derived(*methods)
      self._data_derived = _data_derived + methods.map(&:to_sym)
    end

    def compiled_template_js
      if Rails.env.local?
        mtime = File.mtime(source_path) rescue nil
        if mtime && mtime != @compiled_template_mtime
          @compiled_template_js = nil
          @compiled_template_mtime = mtime
        end
      end

      return @compiled_template_js if defined?(@compiled_template_js) && @compiled_template_js

      require "live_component/live_template_compiler"
      @compiled_template_js = ::LiveComponent::LiveTemplateCompiler.compile(self)
    end

    def source_path
      @source_path ||= begin
        filename = name.gsub(/([a-z])([A-Z])/, '\1_\2').downcase
        Rails.root.join("app/components/#{filename}.rb").to_s
      end
    end

    def data_serializer
      @data_serializer ||= begin
        require "live_component/live_data_serializer"
        ::LiveComponent::LiveDataSerializer.new(self)
      end
    end
  end

  private

  def live_model
    instance_variable_get(:"@#{self.class.live_model_attr}")
  end

  def live_stream_signed_name
    stream = live_model.class.broadcast_configs.first&.dig(:stream)
    return "" unless stream

    stream_parts = stream.is_a?(Proc) ? stream.call(live_model) : stream
    Turbo::StreamsChannel.signed_stream_name(stream_parts)
  end
end
