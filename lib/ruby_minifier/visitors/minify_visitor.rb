require 'prism'

module RubyMinifier
  module Visitors
    class MinifyVisitor < Prism::Visitor
      OPERATORS = %w[+ - * / % ** & | ^ << >> && || < <= > >= == === != =~ !~ <=>].freeze
      NEEDS_PARENS = %w[* / %].freeze

      def initialize
        @result = []
      end

      def visit(node)
        super
        @result.join
      end

      def visit_program_node(node)
        visit(node.statements)
      end

      def visit_statements_node(node)
        node.body.each_with_index do |stmt, i|
          visit(stmt)
          @result << ";" unless i == node.body.length - 1 || stmt.is_a?(Prism::IfNode)
        end
      end

      def visit_def_node(node)
        @result << "def "
        @result << node.name
        if node.parameters && !node.parameters.requireds.empty?
          @result << "("
          visit(node.parameters)
          @result << ")"
        end
        @result << ";"
        visit(node.body)
        @result << ";end"
      end

      def visit_class_node(node)
        @result << "class "
        visit(node.constant_path)
        @result << ";"
        visit(node.body)
        @result << ";end"
      end

      def visit_constant_path_node(node)
        visit(node.child)
      end

      def visit_constant_read_node(node)
        @result << node.name
      end

      def visit_string_node(node)
        @result << node.content.inspect
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
          visit(node.receiver)
          if node.name.to_s.end_with?("=") || !OPERATORS.include?(node.name.to_s)
            @result << "."
            @result << node.name
          else
            @result << node.name
          end
        else
          @result << node.name
        end

        if node.arguments && !node.arguments.arguments.empty?
          needs_parens = !%w[puts print p].include?(node.name.to_s) || 
                        node.arguments.arguments.any? { |arg| arg.is_a?(Prism::CallNode) }
          @result << "(" if needs_parens
          visit(node.arguments)
          @result << ")" if needs_parens
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
        node.requireds.each_with_index do |param, i|
          visit(param)
          @result << "," unless i == node.requireds.length - 1
        end
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
        @result << ";"
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
        left_needs_parens = needs_parens?(node.left, node)
        right_needs_parens = needs_parens?(node.right, node)
        
        @result << "(" if left_needs_parens
        visit(node.left)
        @result << ")" if left_needs_parens
        
        @result << node.operator
        
        @result << "(" if right_needs_parens
        visit(node.right)
        @result << ")" if right_needs_parens
      end

      def visit_if_node(node)
        @result << "if "
        visit(node.predicate)
        @result << ";"
        visit(node.statements)
        if node.consequent
          @result << ";else;"
          visit(node.consequent)
        end
        @result << ";end"
      end

      def visit_array_node(node)
        @result << "["
        node.elements.each_with_index do |elem, i|
          visit(elem)
          @result << "," unless i == node.elements.length - 1
        end
        @result << "]"
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
        visit(node.key)
        @result << ":"
        visit(node.value)
      end

      def visit_symbol_node(node)
        @result << ":"
        @result << node.value
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

      private

      def needs_parens?(node, parent)
        return false unless node.class.name.end_with?("CallNode") || node.class.name.end_with?("BinaryNode")
        return false if node.respond_to?(:operator) && parent.respond_to?(:operator) && 
                       node.operator == parent.operator && %w[+ * && ||].include?(parent.operator)
        
        operator_precedence = {
          "**" => 1,
          "*" => 2, "/" => 2, "%" => 2,
          "+" => 3, "-" => 3,
          "<<" => 4, ">>" => 4,
          "&" => 5,
          "^" => 6,
          "|" => 7,
          "<=" => 8, ">=" => 8, "<" => 8, ">" => 8,
          "==" => 9, "===" => 9, "!=" => 9, "=~" => 9, "!~" => 9,
          "&&" => 10,
          "||" => 11
        }

        return false unless node.respond_to?(:operator) && parent.respond_to?(:operator)
        
        node_precedence = operator_precedence[node.operator] || 0
        parent_precedence = operator_precedence[parent.operator] || 0

        node_precedence > parent_precedence
      end
    end
  end
end
