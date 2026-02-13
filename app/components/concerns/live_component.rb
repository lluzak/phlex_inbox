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

    def compiled_template_js
      @compiled_template_js ||= LiveComponent::Compiler.compile_js(self)
    end

    def encoded_template
      @encoded_template ||= Base64.strict_encode64(compiled_template_js)
    end

    def template_element_id
      @template_element_id ||= "#{name.underscore}_template"
    end
  end
end
