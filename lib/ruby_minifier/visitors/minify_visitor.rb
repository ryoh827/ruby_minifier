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
          # 最後の文でない場合、かつ制御構造でない場合はセミコロンを挿入
          unless i == last_index || is_control_structure?(stmt)
            @result << ";"
          end
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
          receiver_needs_parens = needs_parens?(node.receiver, node)
          @result << "(" if receiver_needs_parens
          visit(node.receiver)
          @result << ")" if receiver_needs_parens

          method_name = node.name.to_s
          if method_name == "[]"
            @result << "["
            visit(node.arguments) if node.arguments
            @result << "]"
            return
          end

          # 演算子メソッドの場合は特別な処理
          if OPERATORS.include?(method_name)
            @result << method_name
          else
            @result << "."
            @result << method_name
          end
        else
          @result << node.name
        end

        if node.arguments && !node.arguments.arguments.empty?
          needs_parens = if OPERATORS.include?(node.name.to_s)
            false
          else
            true
          end
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
        puts "Binary Node Class: #{node.class}"
        puts "Parent Node Class: #{@current_parent.class}" if @current_parent
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

      private

      def needs_parens?(node, parent = nil)
        return false unless parent
        return false unless node.respond_to?(:operator) || node.class.name.end_with?("CallNode")

        if parent.respond_to?(:operator)
          # CallNodeの場合は特別な処理
          if node.class.name.end_with?("CallNode")
            return true if NEEDS_PARENS.include?(parent.operator)
            return false
          end

          # BinaryNodeの場合の処理
          if node.respond_to?(:operator)
            # 同じ演算子の場合は結合的な演算子のみ括弧を省略
            return false if node.operator == parent.operator && %w[+ * && ||].include?(parent.operator)
            
            # 必ず括弧が必要な演算子の場合
            return true if NEEDS_PARENS.include?(node.operator)
            
            node_precedence = OPERATOR_PRECEDENCE[node.operator] || 0
            parent_precedence = OPERATOR_PRECEDENCE[parent.operator] || 0

            # 優先順位が同じか低い場合は括弧が必要
            if node_precedence <= parent_precedence
              # 右結合演算子（**）の場合は特別処理
              return false if node.operator == "**" && parent.operator == "**" && parent.right == node
              return true
            end
          end
        end

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
