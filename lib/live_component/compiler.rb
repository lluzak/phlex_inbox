# frozen_string_literal: true

require "prism"
require "ruby2js"
require "ruby2js/erubi"
require "ruby2js/filter/erb"
require "ruby2js/filter/functions"
require_relative "erb_extractor"

module LiveComponent
  module Compiler
    ESCAPE_FN_JS = <<~JS.freeze
      function _escape(s) {
        return s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#39;");
      }
    JS

    TAG_FN_JS = <<~JS.freeze
      function _tag(name, content, attrs) {
        let html = '<' + name;
        if (attrs) {
          for (let [k, v] of Object.entries(attrs)) {
            if (v == null || v === false) continue;
            if (Array.isArray(v)) v = v.filter(Boolean).join(' ');
            html += ' ' + k + '="' + _escape(String(v)) + '"';
          }
        }
        return html + '>' + _escape(String(content)) + '</' + name + '>';
      }
    JS

    module_function

    def compile(component_class)
      erb_source = read_erb(component_class)
      erb_ruby = Ruby2JS::Erubi.new(erb_source).src

      extraction = { expressions: {}, raw_fields: Set.new }

      nestable_checker = lambda do |class_name|
        klass = class_name.safe_constantize
        return nil unless klass
        return nil unless klass.respond_to?(:compiled_data)
        return nil if klass.respond_to?(:_live_model_attr) && klass._live_model_attr
        begin; read_erb(klass); klass; rescue; nil; end
      end

      js_function = Ruby2JS.convert(
        erb_ruby,
        filters: [:erb, :functions, LiveComponent::ErbExtractor],
        eslevel: 2022,
        extraction: extraction,
        nestable_checker: nestable_checker
      ).to_s

      expressions = extraction[:expressions] || {}
      raw_fields = extraction[:raw_fields] || Set.new
      collection_computed = extraction[:collection_computed] || {}
      nested_components = extraction[:nested_components] || {}

      # Simple @ivars not consumed by extraction become JS params directly
      all_ivars = extract_ivar_names(erb_ruby)
      consumed_ivars = expressions.values
        .flat_map { |src| src.scan(/@(\w+)/).flatten }.to_set
      simple_ivars = (all_ivars - consumed_ivars).to_a.sort

      # Compile nested component templates and embed as JS functions
      nested_functions_js = ""
      nested_components.each do |key, info|
        child_class = info[:class_name].constantize
        child_compiled = compile(child_class)
        child_body = unwrap_function(
          child_compiled[:raw_js_function],
          child_compiled[:fields],
          child_compiled[:raw_fields],
          include_helpers: false
        )
        nested_functions_js += "function _render_#{key}(data) {\n"
        nested_functions_js += child_body.gsub(/^/, "  ") + "\n"
        nested_functions_js += "}\n"
      end

      fields = (expressions.keys + simple_ivars + nested_components.keys).uniq.sort
      parent_raw_body = strip_function_wrapper(js_function)
      js_body = "#{ESCAPE_FN_JS}#{TAG_FN_JS}#{nested_functions_js}"
      js_body += "let { #{fields.join(", ")} } = data;\n"
      js_body += add_html_escaping(parent_raw_body, raw_fields)

      {
        js_body: js_body,
        fields: fields,
        expressions: expressions,
        simple_ivars: simple_ivars,
        collection_computed: collection_computed,
        nested_components: nested_components,
        raw_js_function: js_function,
        raw_fields: raw_fields
      }
    end

    def compile_js(component_class)
      compile(component_class)[:js_body]
    end

    def extract_ivar_names(erb_ruby)
      result = Prism.parse(erb_ruby)
      ivars = Set.new
      walk(result.value) do |node|
        ivars << node.name.to_s.delete_prefix("@") if node.is_a?(Prism::InstanceVariableReadNode)
      end
      ivars
    end

    def read_erb(component_class)
      erb_path = component_class.instance_method(:initialize)
                   .source_location&.first
                   &.sub(/\.rb$/, ".html.erb")

      raise ArgumentError, "Cannot find ERB template for #{component_class}" unless erb_path && File.exist?(erb_path)

      File.read(erb_path)
    end

    def strip_function_wrapper(js_function)
      js_function
        .sub(/\Afunction render\(\{[^}]*\}\) \{\n?/, "")
        .sub(/\}\s*\z/, "")
        .gsub(/^  /, "")
    end

    def unwrap_function(js_function, fields, raw_fields, include_helpers: true)
      body = strip_function_wrapper(js_function)
      destructure = "let { #{fields.join(", ")} } = data;\n"
      escaped_body = add_html_escaping(body, raw_fields)
      helpers = include_helpers ? "#{ESCAPE_FN_JS}#{TAG_FN_JS}" : ""
      "#{helpers}#{destructure}#{escaped_body}"
    end

    def add_html_escaping(body, raw_fields)
      body.gsub(/\+= String\((.+?)\);/) do
        expr = $1
        if raw_fields.include?(expr)
          "+= #{expr};"
        else
          "+= _escape(String(#{expr}));"
        end
      end
    end

    def walk(node, &block)
      yield node
      node.child_nodes.compact.each { |child| walk(child, &block) }
    end
  end
end
