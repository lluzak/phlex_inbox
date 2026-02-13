# frozen_string_literal: true

require "prism"
require "ruby2js"

module LiveComponent
  class LiveTemplateCompiler
    ESCAPE_HTML_JS = "function escapeHtml(t){if(t==null)return'';return String(t).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;');}"

    def self.compile(component_class)
      new(component_class).compile
    rescue StandardError => e
      Rails.logger.debug { "LiveTemplateCompiler: #{e.class}: #{e.message}" } if defined?(Rails)
      nil
    end

    def initialize(component_class)
      @component_class = component_class
      @source_path = component_class.source_path
    end

    def compile
      source = extract_render_html_source
      return nil unless source

      # Strip "self." prefix so ruby2js sees a plain def
      source = source.sub(/\Adef self\./, "def ")

      # Inline constants referenced in the method
      source = inline_constants(source)

      js = Ruby2JS.convert(source, eslevel: 2021, camelCase: false).to_s

      # ruby2js may produce "this.render_html = function(data)" or "function render_html(data)"
      # Normalize to a callable function and return its result
      if js.include?("this.render_html")
        # Convert "this.render_html = function(data) {...}" to callable form
        js = js.sub("this.render_html = function", "function render_html")
      end

      "#{ESCAPE_HTML_JS}\n#{js}\nreturn render_html(data);"
    end

    private

    def extract_render_html_source
      return nil unless File.exist?(@source_path)

      result = Prism.parse_file(@source_path)
      class_node = result.value.statements.body.first
      return nil unless class_node&.body

      class_node.body.body.each do |node|
        next unless node.is_a?(Prism::DefNode)
        next unless node.name == :render_html && node.receiver

        # Use line-based extraction for reliability
        lines = File.readlines(@source_path)
        start_line = node.location.start_line - 1
        end_line = node.location.end_line - 1
        return lines[start_line..end_line].join
      end

      nil
    end

    def inline_constants(source)
      # Replace STARRED_ICON and UNSTARRED_ICON with their string values
      file_content = File.read(@source_path)

      source.gsub(/\b([A-Z][A-Z_]+)\b/) do |const_name|
        # Find the constant definition in the file
        if file_content =~ /#{const_name}\s*=\s*('(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")/
          $1
        else
          const_name
        end
      end
    end
  end
end
