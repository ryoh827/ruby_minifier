module RubyMinifier
  module Visitors
    class MinifyVisitor < Prism::Visitor
      OPERATOR_PRECEDENCE = {
        "**" => 7,
        "*" => 6,
        "/" => 6,
        "%" => 6,
        "+" => 5,
        "-" => 5,
        "<<" => 4,
        ">>" => 4,
        "&" => 3,
        "^" => 2,
        "|" => 1,
        "==" => 0,
        "!=" => 0,
        ">" => 0,
        ">=" => 0,
        "<" => 0,
        "<=" => 0,
        "&&" => 0,
        "||" => 0
      }.freeze

      BINARY_OPERATORS = OPERATOR_PRECEDENCE.keys.freeze

      KEYWORDS = %w[class def if else end do].freeze

      def initialize(configuration = nil)
        @configuration = configuration
        @string_processor = StringProcessor.new(configuration)
      end

      def visit(node)
        return "" unless node
        return node.to_s if node.is_a?(String) || node.is_a?(Symbol) || node.is_a?(Numeric)
        super
      end

      def extract_node_value(node)
        return "" unless node
        return node.to_s if node.is_a?(String) || node.is_a?(Symbol) || node.is_a?(Numeric)
        return node.value.to_s if node.respond_to?(:value) && !node.is_a?(Prism::CallNode)
        return node.content.to_s if node.respond_to?(:content)
        return node.name.to_s if node.respond_to?(:name)
        visit(node)
      end

      def visit_program_node(node)
        @string_processor.process_string(visit(node.statements).to_s)
      end

      def visit_statements_node(node)
        return "" unless node.body
        node.body.map { |statement| visit(statement) }.join(";")
      end

      def visit_def_node(node)
        result = []
        result << "def "
        result << node.name
        result << "(#{visit(node.parameters)})" if node.parameters
        if node.body
          result << ";"
          result << visit(node.body).to_s
        end
        result << ";end"
        result.join
      end

      def visit_parameters_node(node)
        params = []
        if node.requireds
          params.concat(node.requireds.map { |param| param.name.to_s })
        end
        if node.optionals
          params.concat(node.optionals.map { |param| "#{param.name}=#{visit(param.value)}" })
        end
        if node.rest
          params << "*#{node.rest.name}"
        end
        if node.posts
          params.concat(node.posts.map { |param| param.name.to_s })
        end
        if node.keywords
          params.concat(node.keywords.map { |param| "#{param.name}:#{visit(param.value)}" })
        end
        if node.block
          params << "&#{node.block.name}"
        end
        params.join(",")
      end

      def visit_required_parameter_node(node)
        node.name.to_s
      end

      def visit_optional_parameter_node(node)
        "#{node.name}=#{visit(node.value)}"
      end

      def visit_block_parameters_node(node)
        return "" unless node.parameters
        params = []
        if node.parameters.requireds
          params.concat(node.parameters.requireds.map { |param| param.name.to_s })
        end
        if node.parameters.optionals
          params.concat(node.parameters.optionals.map { |param| "#{param.name}=#{visit(param.value)}" })
        end
        if node.parameters.rest
          params << "*#{node.parameters.rest.name}"
        end
        if node.parameters.posts
          params.concat(node.parameters.posts.map { |param| param.name.to_s })
        end
        if node.parameters.keywords
          params.concat(node.parameters.keywords.map { |param| "#{param.name}:#{visit(param.value)}" })
        end
        if node.parameters.block
          params << "&#{node.parameters.block.name}"
        end
        params.join(",")
      end

      def visit_block_node(node)
        parts = []
        if node.parameters
          params = visit(node.parameters)
          parts << "|#{params}|" unless params.empty?
        end
        if node.body
          body = visit(node.body)
          parts << body unless body.empty?
        end
        parts << "end"
        parts.join(";")
      end

      def visit_binary_node(node)
        left = visit(node.left)
        right = visit(node.right)
        operator = node.operator.to_s

        case operator
        when "+", "-", "*", "/", "==", "!=", ">", ">=", "<", "<=", "&&", "||"
          "#{left}#{operator}#{right}"
        else
          "#{left}#{operator}#{right}"
        end
      end

      def visit_if_node(node)
        result = "if #{visit(node.predicate)};"
        if node.statements
          result += visit(node.statements)
        end
        if node.consequent
          result += ";"
          result += visit(node.consequent)
        end
        result += ";end"
        result
      end

      def visit_call_node(node)
        parts = []
        parts << visit(node.receiver) if node.receiver
        parts << node.call_operator if node.call_operator
        parts << node.name

        if node.arguments&.arguments&.any?
          args = node.arguments.arguments.map { |arg| visit(arg) }
          case node.name.to_s
          when "puts"
            content = args.join(", ")
            content = content.gsub(/^"|"$/, '') if content.start_with?('"') && content.end_with?('"')
            parts << " \"#{content}\""
          when "[]"
            parts << "[#{args.join(",")}]"
          else
            parts << "(#{args.join(",")})"
          end
        end

        if node.block
          parts << " do"
          parts << visit(node.block)
        end

        parts.join
      end

      def visit_string_node(node)
        content = node.content.to_s
        if content.include?('"') || content.include?("\#{")
          "'#{content.gsub("'", "\\'")}'"
        else
          "\"#{content}\""
        end
      end

      def visit_string_interpolation_node(node)
        parts = node.parts.map do |part|
          case part
          when Prism::StringNode
            part.content.to_s
          when Prism::EmbeddedStatementsNode
            value = visit(part.statements)
            "\#{#{value}}"
          else
            visit(part)
          end
        end
        "\"#{parts.join}\""
      end

      def visit_embedded_statements_node(node)
        visit(node.statements)
      end

      def visit_arguments_node(node)
        node.arguments.map { |arg| visit(arg) }.join(",")
      end

      def visit_local_variable_read_node(node)
        node.name.to_s
      end

      def visit_local_variable_write_node(node)
        "#{node.name}=#{visit(node.value)}"
      end

      def visit_instance_variable_read_node(node)
        node.name.to_s
      end

      def visit_instance_variable_write_node(node)
        "#{node.name}=#{visit(node.value)}"
      end

      def visit_constant_read_node(node)
        node.name.to_s
      end

      def visit_constant_write_node(node)
        "#{node.name}=#{visit(node.value)}"
      end

      def visit_constant_path_node(node)
        if node.parent
          "#{visit(node.parent)}::#{node.child.name}"
        else
          node.child.name.to_s
        end
      end

      def visit_integer_node(node)
        node.value.to_s
      end

      def visit_float_node(node)
        node.value.to_s
      end

      def visit_true_node(node)
        "true"
      end

      def visit_false_node(node)
        "false"
      end

      def visit_nil_node(node)
        "nil"
      end

      def visit_class_node(node)
        result = []
        result << "class "
        result << visit(node.constant_path)
        result << "<#{visit(node.superclass)}" if node.superclass
        if node.body
          result << ";"
          result << visit(node.body)
        end
        result << ";end"
        result.join
      end

      def visit_hash_node(node)
        elements = node.elements.map { |element| visit(element) }
        "{#{elements.join(",")}}"
      end

      def visit_pair_node(node)
        key = visit(node.key)
        value = visit(node.value)
        "#{key}:#{value}"
      end

      def visit_assoc_node(node)
        "#{visit(node.key)}:#{visit(node.value)}"
      end

      def visit_symbol_node(node)
        ":#{node.value}"
      end

      def visit_array_node(node)
        "[#{node.elements.map { |element| visit(element) }.join(",")}]"
      end

      def visit_else_node(node)
        result = "else"
        if node.statements
          result += ";"
          result += visit(node.statements)
        end
        result
      end

      def visit_range_node(node)
        "#{visit(node.left)}..#{visit(node.right)}"
      end

      def visit_parentheses_node(node)
        if node.body
          visit(node.body)
        else
          "()"
        end
      end

      private

      def needs_parentheses?(operand_precedence, current_precedence, is_right = false)
        return false unless operand_precedence && current_precedence
        is_right ? operand_precedence > current_precedence : operand_precedence >= current_precedence
      end

      def operator_precedence(node)
        return nil unless node.respond_to?(:operator)
        OPERATOR_PRECEDENCE[node.operator.to_s]
      end

      def format_string_literal(content)
        return content if content.start_with?('"') && content.end_with?('"')
        return content if content.start_with?("'") && content.end_with?("'")
        
        if content.include?('"') || content.include?("\#{")
          "'#{content.gsub("'", "\\'")}'"
        else
          "\"#{content}\""
        end
      end

      def add_space_after_keyword(keyword)
        KEYWORDS.include?(keyword.to_s) ? "#{keyword} " : keyword
      end
    end
  end
end 
