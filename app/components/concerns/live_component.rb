# frozen_string_literal: true

module LiveComponent
  extend ActiveSupport::Concern

  included do
    class_attribute :_live_model_attr, instance_writer: false
  end

  class_methods do
    def subscribes_to(attr_name)
      self._live_model_attr = attr_name
    end

    def live_model_attr
      _live_model_attr
    end

    def compiled_data
      @compiled_data ||= LiveComponent::Compiler.compile(self)
    end

    def compiled_template_js
      compiled_data[:js_body]
    end

    def encoded_template
      @encoded_template ||= Base64.strict_encode64(compiled_template_js)
    end

    def template_element_id
      @template_element_id ||= "#{name.underscore}_template"
    end

    def build_data(record, **kwargs)
      evaluator = LiveComponent::DataEvaluator.new(live_model_attr, record, component_class: self, **kwargs)
      data = {}
      collection_computed = compiled_data[:collection_computed] || {}

      compiled_data[:expressions].each do |var_name, ruby_source|
        if collection_computed.key?(var_name)
          data[var_name] = evaluator.evaluate_collection(ruby_source, collection_computed[var_name])
        else
          data[var_name] = evaluator.evaluate(ruby_source)
        end
      end

      compiled_data[:simple_ivars].each do |ivar_name|
        data[ivar_name] = kwargs[ivar_name.to_sym] if kwargs.key?(ivar_name.to_sym)
      end

      data["id"] = record.id
      data["dom_id"] = ActionView::RecordIdentifier.dom_id(record)
      data
    end
  end
end
