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

      js_function = Ruby2JS.convert(
        erb_ruby,
        filters: [:erb, :functions, LiveComponent::ErbExtractor],
        eslevel: 2022,
        extraction: extraction
      ).to_s

      expressions = extraction[:expressions] || {}
      raw_fields = extraction[:raw_fields] || Set.new
      collection_computed = extraction[:collection_computed] || {}

      # Simple @ivars not consumed by extraction become JS params directly
      all_ivars = extract_ivar_names(erb_ruby)
      consumed_ivars = expressions.values
        .flat_map { |src| src.scan(/@(\w+)/).flatten }.to_set
      simple_ivars = (all_ivars - consumed_ivars).to_a.sort

      fields = (expressions.keys + simple_ivars).uniq.sort
      js_body = unwrap_function(js_function, fields, raw_fields)

      {
        js_body: js_body,
        fields: fields,
        expressions: expressions,
        simple_ivars: simple_ivars,
        collection_computed: collection_computed
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

    def unwrap_function(js_function, fields, raw_fields)
      body = js_function
               .sub(/\Afunction render\(\{[^}]*\}\) \{\n?/, "")
               .sub(/\}\s*\z/, "")
               .gsub(/^  /, "")

      destructure = "let { #{fields.join(", ")} } = data;\n"
      escaped_body = add_html_escaping(body, raw_fields)

      "#{ESCAPE_FN_JS}#{TAG_FN_JS}#{destructure}#{escaped_body}"
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
