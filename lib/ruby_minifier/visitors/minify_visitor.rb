require 'prism'

module RubyMinifier
  module Visitors
    class MinifyVisitor < Prism::Visitor
      OPERATORS = %w[+ - * / % ** & | ^ << >> && || < <= > >= == === != =~ !~ <=>].freeze
      NEEDS_PARENS = %w[* / %].freeze

      OPERATOR_PRECEDENCE = {
        "**" => 16,
        "*" => 15, "/" => 15, "%" => 15,
        "+" => 14, "-" => 14,
        "==" => 9, "!=" => 9, ">" => 9, "<" => 9, ">=" => 9, "<=" => 9,
        "&&" => 8,
        "||" => 7
      }.freeze

      def initialize
        @result = []
      end

      def visit(node)
        super
        @result.join.force_encoding("UTF-8")
      end

      def visit_program_node(node)
        visit(node.statements)
      end

      def visit_statements_node(node)
        last_index = node.body.length - 1
        node.body.each_with_index do |stmt, i|
          visit(stmt)
          unless i == last_index || is_control_structure?(stmt) || @current_parent.class.name.end_with?("ParenthesesNode")
            @result << ";"
          end
        end
      end

      def visit_def_node(node)
        @result << "def "
        @result << node.name
        if node.parameters
          @result << "("
          visit(node.parameters)
          @result << ")"
        end
        @result << ";"
        visit(node.body) if node.body
        @result << ";end"
      end

      def visit_class_node(node)
        @result << "class "
        visit(node.constant_path)
        @result << ";"
        visit(node.body) if node.body
        @result << ";end"
      end

      def visit_constant_path_node(node)
        visit(node.child)
      end

      def visit_constant_read_node(node)
        @result << node.name
      end

      def visit_constant_write_node(node)
        @result << node.name
        @result << "="
        visit(node.value)
      end

      def visit_string_node(node)
        if node.content.include?("\#{")
          @result << "\""
          @result << node.content.gsub('"', '\\"')
          @result << "\""
        else
          @result << "\""
          @result << node.content.gsub('"', '\\"')
          @result << "\""
        end
      end

      def visit_integer_node(node)
        @result << node.value.to_s
      end

      def visit_float_node(node)
        @result << node.value.to_s
      end

      def visit_true_node(_)
        @result << "true"
      end

      def visit_false_node(_)
        @result << "false"
      end

      def visit_nil_node(_)
        @result << "nil"
      end

      def visit_call_node(node)
        if node.receiver
          if node.name.to_s == "[]"
            visit(node.receiver)
            @result << "["
            visit(node.arguments) if node.arguments
            @result << "]"
            return
          end

          if OPERATORS.include?(node.name.to_s)
            if node.receiver.class.name.end_with?("ParenthesesNode")
              visit(node.receiver)
            else
              receiver_needs_parens = needs_parens?(node.receiver, node)
              @result << "(" if receiver_needs_parens
              visit(node.receiver)
              @result << ")" if receiver_needs_parens
            end

            @result << node.name.to_s

            if node.arguments && !node.arguments.arguments.empty?
              arg = node.arguments.arguments.first
              if arg.class.name.end_with?("ParenthesesNode")
                visit(arg)
              else
                arg_needs_parens = needs_parens?(arg, node)
                @result << "(" if arg_needs_parens
                visit(arg)
                @result << ")" if arg_needs_parens
              end
            end
          else
            visit(node.receiver)
            @result << "."
            @result << node.name
          end
        else
          @result << node.name.to_s
        end

        if node.arguments && !node.arguments.arguments.empty? && !OPERATORS.include?(node.name.to_s)
          needs_parens = !%w[puts print p].include?(node.name.to_s)
          if needs_parens
            @result << "("
            visit(node.arguments)
            @result << ")"
          else
            first_arg = node.arguments.arguments.first
            if !first_arg.class.name.end_with?("StringNode") && !first_arg.class.name.end_with?("InterpolatedStringNode")
              @result << " "
            end
            visit(node.arguments)
          end
        end

        if node.block
          visit(node.block)
        end
      end

      def visit_arguments_node(node)
        node.arguments.each_with_index do |arg, i|
          visit(arg)
          @result << "," unless i == node.arguments.length - 1
        end
      end

      def visit_parameters_node(node)
        if node.requireds
          node.requireds.each_with_index do |param, i|
            visit(param)
            @result << "," unless i == node.requireds.length - 1 || node.optionals.nil?
          end
        end
        if node.optionals
          node.optionals.each_with_index do |param, i|
            visit(param)
            @result << "," unless i == node.optionals.length - 1
          end
        end
      end

      def visit_optional_parameter_node(node)
        @result << node.name
        @result << "="
        visit(node.value)
      end

      def visit_local_variable_read_node(node)
        @result << node.name
      end

      def visit_local_variable_write_node(node)
        @result << node.name
        @result << "="
        visit(node.value)
      end

      def visit_instance_variable_read_node(node)
        @result << node.name
      end

      def visit_instance_variable_write_node(node)
        @result << node.name
        @result << "="
        visit(node.value)
      end

      def visit_block_node(node)
        @result << " do"
        if node.parameters
          @result << "|"
          visit(node.parameters)
          @result << "|"
        end
        if node.body && node.body.body && !node.body.body.empty?
          @result << ";"
        end
        visit(node.body) if node.body
        @result << ";end"
      end

      def visit_block_parameters_node(node)
        parameters = []
        if node.parameters
          parameters.concat(node.parameters.requireds) if node.parameters.respond_to?(:requireds)
          parameters.concat(node.parameters) if !node.parameters.respond_to?(:requireds)
        end
        parameters.concat(node.locals) if node.locals
        parameters.each_with_index do |param, i|
          visit(param)
          @result << "," unless i == parameters.length - 1
        end
      end

      def visit_required_parameter_node(node)
        @result << node.name
      end

      def visit_local_variable_target_node(node)
        @result << node.name
      end

      def visit_binary_node(node)
        if needs_parens?(node, @current_parent)
          @result << "("
          with_parent(node) do
            visit(node.left)
            @result << node.operator
            visit(node.right)
          end
          @result << ")"
        else
          with_parent(node) do
            visit(node.left)
            @result << node.operator
            visit(node.right)
          end
        end
      end

      def visit_if_node(node)
        if !node.consequent && node.statements && node.statements.body.length == 1
          visit(node.statements)
          @result << " if "
          visit(node.predicate)
        else
          @result << "if "
          visit(node.predicate)
          @result << ";"
          visit(node.statements) if node.statements
          if node.consequent
            @result << ";else;"
            visit(node.consequent)
          end
          @result << ";end"
        end
      end

      def visit_array_node(node)
        @result << "["
        node.elements.each_with_index do |elem, i|
          visit(elem)
          @result << "," unless i == node.elements.length - 1
        end
        @result << "]"
      end

      def visit_parentheses_node(node)
        @result << "("
        visit(node.body)
        @result << ")"
      end

      def visit_hash_node(node)
        @result << "{"
        node.elements.each_with_index do |elem, i|
          visit(elem)
          @result << "," unless i == node.elements.length - 1
        end
        @result << "}"
      end

      def visit_assoc_node(node)
        if node.key.class.name.end_with?("SymbolNode")
          @result << node.key.value
          @result << ":"
        else
          visit(node.key)
          @result << ":"
        end
        visit(node.value)
      end

      def visit_string_interpolation_node(node)
        @result << "\""
        node.parts.each do |part|
          case part
          when Prism::StringNode
            @result << part.content.gsub('"', '\\"')
          when Prism::EmbeddedStatementsNode
            @result << "\#{"
            visit(part.statements)
            @result << "}"
          end
        end
        @result << "\""
      end

      def visit_index_node(node)
        visit(node.receiver)
        @result << "["
        visit(node.index)
        @result << "]"
      end

      def visit_range_node(node)
        visit(node.left)
        @result << ".."
        visit(node.right)
      end

      def visit_embedded_statements_node(node)
        visit(node.statements)
      end

      def visit_symbol_node(node)
        if node.value.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
          @result << ":"
          @result << node.value
        else
          @result << node.value.inspect
        end
      end

      def visit_interpolated_string_node(node)
        @result << "\""
        node.parts.each do |part|
          case part
          when Prism::StringNode
            @result << part.content.gsub('"', '\\"')
          else
            @result << "\#{"
            visit(part)
            @result << "}"
          end
        end
        @result << "\""
      end

      def visit_and_node(node)
        if node.left.class.name.end_with?("ParenthesesNode")
          visit(node.left)
        else
          left_needs_parens = needs_parens?(node.left, node)
          @result << "(" if left_needs_parens
          visit(node.left)
          @result << ")" if left_needs_parens
        end

        @result << "&&"

        if node.right.class.name.end_with?("ParenthesesNode")
          visit(node.right)
        else
          right_needs_parens = needs_parens?(node.right, node)
          @result << "(" if right_needs_parens
          visit(node.right)
          @result << ")" if right_needs_parens
        end
      end

      def visit_or_node(node)
        if node.left.class.name.end_with?("ParenthesesNode")
          visit(node.left)
        else
          left_needs_parens = needs_parens?(node.left, node)
          @result << "(" if left_needs_parens
          visit(node.left)
          @result << ")" if left_needs_parens
        end

        @result << "||"

        if node.right.class.name.end_with?("ParenthesesNode")
          visit(node.right)
        else
          right_needs_parens = needs_parens?(node.right, node)
          @result << "(" if right_needs_parens
          visit(node.right)
          @result << ")" if right_needs_parens
        end
      end

      private

      def needs_parens?(node, parent = nil)
        return false unless parent

        if parent.class.name.end_with?("AndNode") || parent.class.name.end_with?("OrNode")
          if node.class.name.end_with?("AndNode") || node.class.name.end_with?("OrNode")
            return false if (parent.class.name.end_with?("AndNode") && node.class.name.end_with?("AndNode")) ||
                          (parent.class.name.end_with?("OrNode") && node.class.name.end_with?("OrNode"))
            parent_precedence = parent.class.name.end_with?("AndNode") ? 8 : 7
            node_precedence = node.class.name.end_with?("AndNode") ? 8 : 7
            return node_precedence <= parent_precedence
          end
        end

        if parent.respond_to?(:operator)
          if node.class.name.end_with?("CallNode")
            return true if NEEDS_PARENS.include?(parent.operator)
            return false
          end

          if node.respond_to?(:operator)
            return false if node.operator == parent.operator && %w[+ * && ||].include?(parent.operator)
            
            return true if NEEDS_PARENS.include?(node.operator)
            
            node_precedence = OPERATOR_PRECEDENCE[node.operator] || 0
            parent_precedence = OPERATOR_PRECEDENCE[parent.operator] || 0

            if node_precedence <= parent_precedence
              return false if node.operator == "**" && parent.operator == "**" && parent.right == node
              return true
            end
          end
        end

        return true if node.class.name.end_with?("ParenthesesNode")

        false
      end

      def is_control_structure?(node)
        node.class.name.end_with?("IfNode") ||
        node.class.name.end_with?("WhileNode") ||
        node.class.name.end_with?("UntilNode") ||
        node.class.name.end_with?("CaseNode") ||
        node.class.name.end_with?("ForNode") ||
        node.class.name.end_with?("BeginNode") ||
        node.class.name.end_with?("RescueNode") ||
        node.class.name.end_with?("EnsureNode")
      end
    end
  end
end
