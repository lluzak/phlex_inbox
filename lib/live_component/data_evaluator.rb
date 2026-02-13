# frozen_string_literal: true

module LiveComponent
  class DataEvaluator
    include ActionView::Helpers::DateHelper
    include ActionView::Helpers::TextHelper
    include ActionView::Helpers::NumberHelper
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::OutputSafetyHelper
    include Rails.application.routes.url_helpers

    def initialize(model_attr, record, component_class: nil, **kwargs)
      instance_variable_set(:"@#{model_attr}", record)
      kwargs.each { |k, v| instance_variable_set(:"@#{k}", v) }
      @component_delegate = component_class&.allocate
    end

    def evaluate(ruby_source)
      instance_eval(ruby_source)
    rescue => e
      Rails.logger.error "[LiveComponent::DataEvaluator] Error evaluating '#{ruby_source}': #{e.message}"
      nil
    end

    def evaluate_collection(ruby_source, computed)
      collection = instance_eval(ruby_source)
      block_var = computed[:block_var]

      lambdas = {}
      (computed[:expressions] || {}).each do |var_name, info|
        lambdas[var_name] = instance_eval("lambda { |#{block_var}| #{info[:source]} }")
      end

      collection.map do |item|
        lambdas.each_with_object({}) do |(var_name, fn), result|
          result[var_name] = fn.call(item).to_s
        end
      end
    end

    def default_url_options
      Rails.application.routes.default_url_options
    end

    private

    def method_missing(method, *args, **kwargs, &block)
      if component_own_method?(method)
        @component_delegate.send(method, *args, **kwargs, &block)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      component_own_method?(method) || super
    end

    def component_own_method?(method)
      return false unless @component_delegate
      klass = @component_delegate.class
      klass.instance_methods(false).include?(method) ||
        klass.private_instance_methods(false).include?(method)
    end
  end
end
