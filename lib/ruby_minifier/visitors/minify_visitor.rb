module RubyMinifier
  module Visitors
    class MinifyVisitor < Prism::Visitor
      OPERATOR_PRECEDENCE = {
        "**" => 1,
        "*" => 2, "/" => 2, "%" => 2,
        "+" => 3, "-" => 3,
        "<<" => 4, ">>" => 4,
        "&" => 5,
        "^" => 6,
        "|" => 7,
        "<=" => 8, ">=" => 8, "<" => 8, ">" => 8,
        "==" => 9, "!=" => 9, "===" => 9,
        "&&" => 10,
        "||" => 11
      }.freeze

      def initialize
        super()
      end

      def visit(node)
        return "" unless node
        node.accept(self)
      end

      def visit_program_node(node)
        visit_statements_node(node.statements)
      end

      def visit_statements_node(node)
        return "" unless node&.body
        node.body.map { |n| visit(n) }.join(";")
      end

      def visit_def_node(node)
        name = node.name.to_s
        params = visit(node.parameters)
        body = visit(node.body)
        "def #{name}#{params};#{body};end"
      end

      def visit_class_node(node)
        name = visit(node.constant_path)
        body = visit(node.body)
        "class #{name};#{body};end"
      end

      def visit_constant_path_node(node)
        if node.parent
          "#{visit(node.parent)}::#{visit(node.child)}"
        else
          visit(node.child)
        end
      end

      def visit_constant_read_node(node)
        node.name.to_s
      end

      def visit_call_node(node)
        receiver = visit(node.receiver)
        name = node.name.to_s
        args = visit(node.arguments)
        block = visit(node.block)

        if binary_operator?(name)
          handle_binary_operator(receiver, name, args)
        else
          handle_method_call(receiver, name, args, block)
        end
      end

      def visit_string_node(node)
        "\"#{node.content}\""
      end

      def visit_string_interpolation_node(node)
        parts = node.parts.map do |part|
          if part.is_a?(Prism::StringNode)
            part.content
          else
            "\#{#{visit(part)}}"
          end
        end.join
        "\"#{parts}\""
      end

      def visit_arguments_node(node)
        return "" unless node&.arguments
        node.arguments.map { |arg| visit(arg) }.join(",")
      end

      def visit_parameters_node(node)
        return "" unless node
        params = []
        params.concat(node.requireds.map { |param| param.name }) if node.requireds
        params.concat(node.optionals.map { |param| "#{param.name}=#{visit(param.value)}" }) if node.optionals
        params << "*#{node.rest.name}" if node.rest
        params.empty? ? "" : "(#{params.join(",")})"
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

      def visit_integer_node(node)
        node.value.to_s
      end

      def visit_if_node(node)
        predicate = visit(node.predicate)
        statements = visit(node.statements)
        else_clause = node.consequent ? ";else;#{visit(node.consequent)}" : ""
        "if #{predicate};#{statements}#{else_clause};end"
      end

      def visit_else_node(node)
        visit(node.statements)
      end

      def visit_block_node(node)
        params = visit(node.parameters)
        body = visit(node.body)
        " do#{params};#{body};end"
      end

      def visit_block_parameters_node(node)
        return "" unless node&.parameters
        params = []
        params.concat(node.parameters.requireds.map { |param| visit(param) }) if node.parameters.requireds
        params.concat(node.parameters.optionals.map { |param| visit(param) }) if node.parameters.optionals
        params << visit(node.parameters.rest) if node.parameters.rest
        params.empty? ? "" : "|#{params.join(",")}|"
      end

      private

      def binary_operator?(name)
        OPERATOR_PRECEDENCE.key?(name)
      end

      def handle_binary_operator(left, operator, right)
        current_precedence = OPERATOR_PRECEDENCE[operator]
        left_precedence = get_precedence(left)
        right_precedence = get_precedence(right)

        left = parenthesize?(left_precedence, current_precedence) ? "(#{left})" : left
        right = parenthesize?(right_precedence, current_precedence) ? "(#{right})" : right

        "#{left}#{operator}#{right}"
      end

      def handle_method_call(receiver, name, args, block)
        receiver_part = receiver.empty? ? "" : "#{receiver}."
        args_part = args.empty? ? "" : "(#{args})"
        "#{receiver_part}#{name}#{args_part}#{block}"
      end

      def get_precedence(node)
        return OPERATOR_PRECEDENCE[node.operator] if node.is_a?(Prism::BinaryNode)
        nil
      end

      def parenthesize?(child_precedence, parent_precedence)
        child_precedence && child_precedence > parent_precedence
      end
    end
  end
end 







