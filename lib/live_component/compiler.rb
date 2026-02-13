# frozen_string_literal: true

require "erb"
require "prism"
require "ruby2js"
require "ruby2js/filter/erb"
require "ruby2js/filter/functions"

module LiveComponent
  module Compiler
    ESCAPE_FN_JS = <<~JS.freeze
      function _escape(s) {
        return s.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#39;");
      }
    JS

    module_function

    def compile(component_class)
      erb_source = read_erb(component_class)

      # Pre-process: strip raw() calls and track which fields are raw
      raw_fields = Set.new
      cleaned_erb = erb_source.gsub(/<%=\s*raw\s+@(\w+)\s*%>/) do
        raw_fields << $1
        "<%= @#{$1} %>"
      end

      erb_ruby = ERB.new(cleaned_erb).src
      fields = extract_fields(erb_ruby)
      js_function = Ruby2JS.convert(erb_ruby, filters: [ :erb, :functions ], eslevel: 2022).to_s
      js_body = unwrap_function(js_function, fields, raw_fields)

      { js_body: js_body, fields: fields }
    end

    def compile_js(component_class)
      compile(component_class)[:js_body]
    end

    def extract_fields(erb_ruby)
      result = Prism.parse(erb_ruby)
      ivars = Set.new
      walk(result.value) do |node|
        ivars << node.name.to_s.delete_prefix("@") if node.is_a?(Prism::InstanceVariableReadNode)
      end
      ivars.to_a.sort
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

      "#{ESCAPE_FN_JS}#{destructure}#{escaped_body}"
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
