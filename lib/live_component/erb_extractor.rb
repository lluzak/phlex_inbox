# frozen_string_literal: true

require "ruby2js"

module LiveComponent
  module ErbExtractor
    include Ruby2JS::Filter::SEXP

    def initialize(*args)
      super
      @extracted_expressions = {}
      @extracted_raw_fields = Set.new
      @block_context_stack = []
      @key_counter = 0
      @source_to_key = {} # source string -> assigned key (scalar dedup)
    end

    def set_options(options)
      super
      @extraction_output = @options[:extraction]
    end

    # Intercept .each blocks to track block variable context.
    # We override process() rather than on_block because the ERB filter
    # sits above us in the MRO for on_block, so our override never gets
    # called. By hooking process(), we push context BEFORE the normal
    # handler chain (ERB -> Functions) runs, so process_erb_send_append
    # sees the block context when processing the body.
    def process(node)
      return super unless node.respond_to?(:type) && node.type == :block

      call, args = node.children
      return super unless call.type == :send

      target, method = call.children
      return super unless method == :each

      block_var = args.children.first&.children&.first
      return super unless block_var

      collection_source = ivar_chain?(target) ? rebuild_source(target) : nil

      @block_context_stack.push(
        var: block_var,
        computed: {},
        collection_source: collection_source,
        collection_key: nil
      )
      result = super
      context = @block_context_stack.pop
      flush_block_computed(context) if context[:collection_key]
      result
    end

    # Hook called by ERB filter for expressions inside <%= %> tags.
    def process_erb_send_append(send_node)
      target, method, *args = send_node.children

      # raw(expr) -- extract inner expression, mark as raw
      if target.nil? && method == :raw && args.length == 1
        inner = args.first
        if extractable?(inner)
          key = record_extraction(inner, raw: true)
          return s(:op_asgn, s(:lvasgn, @erb_bufvar), :+, s(:lvar, key.to_sym))
        end
        return defined?(super) ? super : nil
      end

      # tag.span(content, class: "...") — build tag in JS
      if tag_builder?(target)
        return process_tag_builder_append(send_node)
      end

      # @ivar.chain (e.g., @message.sender.name)
      if ivar_chain?(send_node)
        key = record_extraction(send_node)
        return s(:op_asgn, s(:lvasgn, @erb_bufvar), :+,
                 s(:send, nil, :String, s(:lvar, key.to_sym)))
      end

      # bare_helper(@args) where args reference ivars (e.g., message_path(@message))
      if target.nil? && contains_ivar?(send_node)
        key = record_extraction(send_node)
        return s(:op_asgn, s(:lvasgn, @erb_bufvar), :+,
                 s(:send, nil, :String, s(:lvar, key.to_sym)))
      end

      # Inside a .each block: expressions referencing the block variable
      # become per-item computed fields
      if in_block_context? && contains_block_var?(send_node)
        raw = html_producing?(send_node)
        key = record_block_computed(send_node, raw: raw)
        block_var = current_block_context[:var]
        prop = s(:send, s(:lvar, block_var), :[], s(:str, key))
        if raw
          return s(:op_asgn, s(:lvasgn, @erb_bufvar), :+, prop)
        else
          return s(:op_asgn, s(:lvasgn, @erb_bufvar), :+,
                   s(:send, nil, :String, prop))
        end
      end

      # Fallback: any remaining expression that doesn't reference block
      # variables becomes a server-computed variable.
      unless lvar_chain?(send_node) || contains_lvar?(send_node)
        raw = html_producing?(send_node)
        key = record_extraction(send_node, raw: raw)
        if raw
          return s(:op_asgn, s(:lvasgn, @erb_bufvar), :+, s(:lvar, key.to_sym))
        else
          return s(:op_asgn, s(:lvasgn, @erb_bufvar), :+,
                   s(:send, nil, :String, s(:lvar, key.to_sym)))
        end
      end

      defined?(super) ? super : nil
    end

    # Catches ivar chains in non-output context (if/unless conditions, ternaries).
    def on_send(node)
      return super unless @erb_bufvar

      target, method, *args = node.children

      if ivar_chain?(node)
        source = rebuild_source(node)

        # Collection being iterated: assign a unique key per loop
        if in_block_context? && current_block_context[:collection_source] == source && current_block_context[:collection_key].nil?
          key = record_collection_extraction(node)
          current_block_context[:collection_key] = key
        else
          key = record_extraction(node)
        end

        return s(:lvar, key.to_sym)
      end

      super
    end

    private

    # --- Tag builder ---

    def process_tag_builder_append(send_node)
      _target, method, *args = send_node.children
      tag_name = method.to_s

      # Separate positional args from keyword hash
      positional = args.dup
      hash_arg = (ast_node?(positional.last) && positional.last.type == :hash) ? positional.pop : nil
      content_node = positional.first

      content_expr = content_node ? process_tag_arg(content_node) : s(:str, "")

      if hash_arg
        attrs_expr = process_tag_attrs(hash_arg)
        call = s(:send, nil, :_tag, s(:str, tag_name), content_expr, attrs_expr)
      else
        call = s(:send, nil, :_tag, s(:str, tag_name), content_expr)
      end

      # _tag returns raw HTML (handles its own escaping)
      s(:op_asgn, s(:lvasgn, @erb_bufvar), :+, call)
    end

    def process_tag_arg(node)
      return process(node) unless ast_node?(node)

      if node.type == :array
        return s(:array, *node.children.map { |child| process_tag_arg(child) })
      end

      if ivar_chain?(node)
        key = record_extraction(node)
        return s(:lvar, key.to_sym)
      end

      if node.type == :send && node.children[0].nil? && contains_ivar?(node)
        key = record_extraction(node)
        return s(:lvar, key.to_sym)
      end

      if in_block_context? && contains_block_var?(node)
        key = record_block_computed(node)
        block_var = current_block_context[:var]
        return s(:send, s(:lvar, block_var), :[], s(:str, key))
      end

      process(node)
    end

    def process_tag_attrs(hash_node)
      pairs = hash_node.children.map do |pair|
        next pair unless ast_node?(pair) && pair.type == :pair
        key_node, value_node = pair.children
        js_key = (ast_node?(key_node) && key_node.type == :sym) ? s(:str, key_node.children[0].to_s) : key_node
        processed_value = process_tag_arg(value_node)
        s(:pair, js_key, processed_value)
      end
      s(:hash, *pairs)
    end

    # --- Key generation ---

    def next_key
      key = "v#{@key_counter}"
      @key_counter += 1
      key
    end

    # --- Block context tracking ---

    def in_block_context?
      !@block_context_stack.empty?
    end

    def current_block_context
      @block_context_stack.last
    end

    def contains_block_var?(node)
      return false unless in_block_context?
      contains_specific_lvar?(node, current_block_context[:var])
    end

    def contains_specific_lvar?(node, var_name)
      return false unless ast_node?(node)
      return true if node.type == :lvar && node.children[0] == var_name
      node.children.any? { |child| ast_node?(child) && contains_specific_lvar?(child, var_name) }
    end

    def record_block_computed(node, raw: false)
      source = rebuild_source(node)
      computed = current_block_context[:computed]

      # Dedup within this block: same source reuses same key
      existing = computed.find { |_, info| info[:source] == source }
      return existing[0] if existing

      key = next_key
      computed[key] = { source: source, raw: raw }
      key
    end

    def flush_block_computed(context)
      return unless @extraction_output
      key = context[:collection_key]
      return unless key

      @extraction_output[:collection_computed] ||= {}
      @extraction_output[:collection_computed][key] = {
        block_var: context[:var].to_s,
        expressions: context[:computed]
      }
    end

    # --- AST inspection helpers ---

    def ivar_chain?(node)
      return false unless node && ast_node?(node)
      return true if node.type == :ivar
      return false unless node.type == :send
      target = node.children[0]
      target && ivar_chain?(target)
    end

    def ivar_chain_to_name(node)
      parts = []
      current = node
      while current && ast_node?(current) && current.type == :send
        parts.unshift(current.children[1].to_s.delete_suffix("?"))
        current = current.children[0]
      end
      parts.join("_")
    end

    def extractable?(node)
      return false unless ast_node?(node)
      ivar_chain?(node) || (node.type == :send && node.children[0].nil? && contains_ivar?(node))
    end

    def contains_ivar?(node)
      return false unless ast_node?(node)
      return true if node.type == :ivar
      node.children.any? { |child| ast_node?(child) && contains_ivar?(child) }
    end

    def contains_lvar?(node)
      return false unless ast_node?(node)
      return true if node.type == :lvar
      node.children.any? { |child| ast_node?(child) && contains_lvar?(child) }
    end

    def lvar_chain?(node)
      return false unless node && ast_node?(node)
      return true if node.type == :lvar
      return false unless node.type == :send
      node.children[0] && lvar_chain?(node.children[0])
    end

    HTML_PRODUCING_METHODS = %i[content_tag link_to button_to image_tag].to_set.freeze

    def html_producing?(node)
      return false unless node.type == :send
      target, method = node.children
      return true if tag_builder?(target)
      return true if target.nil? && HTML_PRODUCING_METHODS.include?(method)
      false
    end

    def tag_builder?(node)
      node&.type == :send && node.children == [nil, :tag]
    end

    # --- Source reconstruction ---

    def rebuild_source(node)
      return "" unless ast_node?(node)
      case node.type
      when :ivar then node.children[0].to_s
      when :lvar then node.children[0].to_s
      when :str then node.children[0].inspect
      when :int, :float then node.children[0].to_s
      when :true then "true"
      when :false then "false"
      when :nil then "nil"
      when :sym then ":#{node.children[0]}"
      when :hash
        node.children.map { |pair| rebuild_source(pair) }.join(", ")
      when :pair
        key, value = node.children
        if key.type == :sym
          "#{key.children[0]}: #{rebuild_source(value)}"
        else
          "#{rebuild_source(key)} => #{rebuild_source(value)}"
        end
      when :send
        target, method, *args = node.children
        recv = target ? rebuild_source(target) : nil
        args_src = args.map { |a| rebuild_source(a) }.join(", ")
        method_str = method.to_s
        if recv
          args.empty? ? "#{recv}.#{method_str}" : "#{recv}.#{method_str}(#{args_src})"
        else
          "#{method_str}(#{args_src})"
        end
      else ""
      end
    end

    # --- Extraction recording ---

    # Scalar: same source reuses same key.
    def record_extraction(node, raw: false)
      source = rebuild_source(node)

      if @source_to_key.key?(source)
        key = @source_to_key[source]
        @extracted_raw_fields << key if raw
        return key
      end

      key = next_key
      @source_to_key[source] = key
      @extracted_expressions[key] = source
      @extracted_raw_fields << key if raw
      flush_extraction_output
      key
    end

    # Collection: always unique (no dedup), each loop gets its own key.
    def record_collection_extraction(node)
      source = rebuild_source(node)
      key = next_key
      @extracted_expressions[key] = source
      flush_extraction_output
      key
    end

    def flush_extraction_output
      return unless @extraction_output
      @extraction_output[:expressions] = @extracted_expressions.dup
      @extraction_output[:raw_fields] = @extracted_raw_fields.dup
    end
  end
end
