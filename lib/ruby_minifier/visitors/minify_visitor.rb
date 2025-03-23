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
        result = @result.join
        result.gsub(/^# encoding: [A-Z0-9-]+\n#\s+valid: true\n/, '')
      end

      def visit_program_node(node)
        visit(node.statements)
        @result = @result.reject { |part| part.match?(/^# encoding: [A-Z0-9-]+$/) || part.match?(/^#\s+valid: true$/) }
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
        @result << "\""
        @result << node.content.gsub('"', '\\"')
        @result << "\""
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
        # レシーバーの処理
        if node.receiver
          receiver_needs_parens = needs_parens?(node.receiver, node)
          @result << "(" if receiver_needs_parens
          visit(node.receiver)
          @result << ")" if receiver_needs_parens

          # メソッド名の処理
          method_name = node.name.to_s
          if method_name.end_with?("=") || !OPERATORS.include?(method_name)
            @result << "."
            @result << method_name
          else
            # 演算子メソッドの場合は直接演算子を出力
            @result << method_name
          end
        else
          @result << node.name
        end

        # 引数の処理
        if node.arguments && !node.arguments.arguments.empty?
          # 演算子メソッドまたは特別なメソッドの場合は括弧を省略可能
          needs_parens = if OPERATORS.include?(node.name.to_s)
            false
          else
            !%w[puts print p].include?(node.name.to_s) || 
            node.arguments.arguments.any? { |arg| arg.class.name.end_with?("CallNode") || arg.class.name.end_with?("BinaryNode") }
          end
          @result << "(" if needs_parens
          visit(node.arguments)
          @result << ")" if needs_parens
        end

        # ブロックの処理
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

      def visit_string_interpolation_node(node)
        @result << "\""
        node.parts.each do |part|
          case part
          when Prism::StringNode
            @result << part.content.gsub('"', '\\"')
          when Prism::EmbeddedStatementsNode
            @result << "\#{"
            # 一時的に結果を保存
            current_size = @result.size
            visit(part.statements)
            # 補完部分の結果を取得
            interpolated = @result[current_size..-1].join
            # 余分なクォートを削除
            interpolated = interpolated.gsub(/\A"(.*)"\z/, '\1') if interpolated.start_with?('"') && interpolated.end_with?('"')
            # 結果を更新
            @result = @result[0...current_size]
            @result << interpolated
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

      private

      def needs_parens?(node, parent)
        return false unless node.class.name.end_with?("CallNode") || node.class.name.end_with?("BinaryNode")
        
        # CallNodeの場合は特別な処理
        if node.class.name.end_with?("CallNode")
          return false unless parent.class.name.end_with?("BinaryNode")
          return true if parent.respond_to?(:operator) && NEEDS_PARENS.include?(parent.operator)
          return false
        end
        
        # 同じ演算子の場合の特別処理
        if node.respond_to?(:operator) && parent.respond_to?(:operator)
          return false if node.operator == parent.operator && %w[+ * && ||].include?(parent.operator)
          
          # NEEDS_PARENSに含まれる演算子の場合は必ず括弧が必要
          return true if NEEDS_PARENS.include?(node.operator)
          
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
          
          node_precedence = operator_precedence[node.operator] || 0
          parent_precedence = operator_precedence[parent.operator] || 0

          # 優先順位が同じ場合は右結合の演算子（**）のみ括弧が必要
          return true if node_precedence == parent_precedence && node.operator == "**"
          
          # 左辺の場合は優先順位が同じでも括弧が必要
          if parent.left == node
            return node_precedence >= parent_precedence
          end
          
          return node_precedence > parent_precedence
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
