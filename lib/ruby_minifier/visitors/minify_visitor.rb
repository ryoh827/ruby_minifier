require 'prism'

module RubyMinifier
  module Visitors
    class MinifyVisitor < Prism::Visitor
      def initialize
        @result = []
      end

      def visit(node)
        super
        @result.join
      end

      def visit_program_node(node)
        visit_all(node.statements)
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
        if node.parameters
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
          @result << "."
        end
        @result << node.name
        if node.arguments
          @result << "("
          visit(node.arguments)
          @result << ")"
        end
      end

      def visit_arguments_node(node)
        node.arguments.each_with_index do |arg, i|
          visit(arg)
          @result << "," unless i == node.arguments.length - 1
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
        visit(node.body)
        @result << ";end"
      end

      def visit_block_parameters_node(node)
        node.parameters.each_with_index do |param, i|
          visit(param)
          @result << "," unless i == node.parameters.length - 1
        end
      end

      def visit_required_parameter_node(node)
        @result << node.name
      end

      def visit_binary_node(node)
        visit(node.left)
        @result << node.operator
        visit(node.right)
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
          if part.is_a?(Prism::StringNode)
            @result << part.content
          else
            @result << "\#{"
            visit(part)
            @result << "}"
          end
        end
        @result << "\""
      end
    end
  end
end
