# frozen_string_literal: true

module Dev
  class LiveComponentsController < ApplicationController
    COMPONENT_CLASSES = [
      MessageRowComponent,
      MessageDetailComponent,
      MessageLabelsComponent
    ].freeze

    def index
      @components = COMPONENT_CLASSES.map do |klass|
        erb_source = LiveComponent::Compiler.read_erb(klass)
        data = klass.compiled_data

        {
          name: klass.name,
          erb_source: erb_source,
          js_body: data[:js_body],
          expressions: data[:expressions],
          simple_ivars: data[:simple_ivars],
          collection_computed: data[:collection_computed]
        }
      rescue => e
        {
          name: klass.name,
          erb_source: erb_source || "Error reading ERB: #{e.message}",
          error: "#{e.class}: #{e.message}",
          backtrace: e.backtrace
        }
      end
    end
  end
end
