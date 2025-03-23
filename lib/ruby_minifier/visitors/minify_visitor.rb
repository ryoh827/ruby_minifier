module RubyMinifier
  module Visitors
    class MinifyVisitor < Prism::Visitor
      OPERATORS = {
        "+" => "+",
        "-" => "-",
        "*" => "*",
        "/" => "/",
        "==" => "==",
        "!=" => "!=",
        "&&" => "&&",
        "||" => "||",
        "<" => "<",
        ">" => ">",
        "<=" => "<=",
        ">=" => ">=",
        "[]" => "[]",
        "<<" => "<<",
      }

      OPERATOR_PRECEDENCE = {
        "||" => 1,
        "&&" => 2,
        "==" => 3,
        "!=" => 3,
        "<" => 3,
        ">" => 3,
        "<=" => 3,
        ">=" => 3,
        "+" => 4,
        "-" => 4,
        "*" => 5,
        "/" => 5,
        "[]" => 6,
        "<<" => 6,
      }

      def initialize(configuration)
        @configuration = configuration
        @output = String.new
        @previous_token = nil
        @needs_semicolon = false
        @in_block = false
        @in_method = false
      end

      def visit_program_node(node)
        node.statements.accept(self)
        @output
      end

      def visit_statements_node(node)
        return unless node.body

        node.body.each_with_index do |statement, index|
          # Add semicolon before statement if needed
          if @needs_semicolon && !statement.is_a?(Prism::DefNode) && !statement.is_a?(Prism::ClassNode)
            @output << ";"
            @needs_semicolon = false
          end

          # Process the statement
          statement.accept(self)

          # Set semicolon flag for next statement
          unless statement.is_a?(Prism::DefNode) || 
                 statement.is_a?(Prism::ClassNode) || 
                 statement.is_a?(Prism::ModuleNode) ||
                 statement.is_a?(Prism::BlockNode) ||
                 statement.is_a?(Prism::IfNode) ||
                 statement.is_a?(Prism::WhileNode) ||
                 statement.is_a?(Prism::UntilNode)
            @needs_semicolon = true
          end
        end
      end

      def visit_def_node(node)
        was_in_method = @in_method
        @in_method = true
        @output << "def "
        @output << node.name.to_s
        if node.parameters
          @output << "("
          node.parameters.accept(self)
          @output << ")"
        end
        if node.body
          @output << ";"
          node.body.accept(self)
        end
        @output << "end"
        @in_method = was_in_method
        @needs_semicolon = true
      end

      def visit_class_node(node)
        @output << "class "
        node.constant_path.accept(self)
        @output << ";"
        node.body.accept(self)
        @output << "end"
        @needs_semicolon = true
      end

      def visit_module_node(node)
        @output << "module "
        node.constant_path.accept(self)
        @output << ";"
        node.body.accept(self)
        @output << "end"
        @needs_semicolon = true
      end

      def visit_constant_path_node(node)
        node.parts.each_with_index do |part, index|
          @output << "::" if index > 0
          part.accept(self)
        end
      end

      def visit_constant_read_node(node)
        @output << node.name.to_s
      end

      def visit_identifier_node(node)
        @output << node.name.to_s
      end

      def visit_string_node(node)
        content = node.content.to_s
        if content.include?('"') && !content.include?("'")
          @output << "'" << content.gsub("\\", "\\\\").gsub("'", "\\\\'") << "'"
        else
          @output << '"' << content.gsub("\\", "\\\\").gsub('"', '\\"') << '"'
        end
      end

      def visit_integer_node(node)
        @output << node.value.to_s
      end

      def needs_parentheses?(node, parent_precedence)
        return false unless node.is_a?(Prism::CallNode)
        operator = OPERATORS[node.name.to_s]
        return false unless operator
        node_precedence = OPERATOR_PRECEDENCE[operator]
        node_precedence < parent_precedence
      end

      def visit_call_node(node)
        operator = OPERATORS[node.name.to_s]
        if operator && node.receiver && node.arguments && node.arguments.arguments.length == 1
          # Handle binary operators
          current_precedence = OPERATOR_PRECEDENCE[operator]
          
          # Handle receiver
          if needs_parentheses?(node.receiver, current_precedence)
            @output << "("
            node.receiver.accept(self)
            @output << ")"
          else
            node.receiver.accept(self)
          end

          if operator == "[]"
            @output << operator[0]
            node.arguments.arguments.first.accept(self)
            @output << operator[1]
          else
            @output << operator

            # Handle argument
            arg = node.arguments.arguments.first
            if needs_parentheses?(arg, current_precedence)
              @output << "("
              arg.accept(self)
              @output << ")"
            else
              arg.accept(self)
            end
          end
        else
          # Handle normal method calls
          if node.receiver
            node.receiver.accept(self)
            @output << "."
          end
          @output << node.name.to_s
          if node.arguments
            @output << "("
            node.arguments.accept(self)
            @output << ")"
          end
          if node.block
            node.block.accept(self)
          end
        end
        @needs_semicolon = true
      end

      def visit_arguments_node(node)
        node.arguments.each_with_index do |arg, index|
          @output << "," if index > 0
          arg.accept(self)
        end
      end

      def visit_block_node(node)
        was_in_block = @in_block
        @in_block = true
        
        @output << " do"
        if node.parameters
          @output << "|"
          node.parameters.accept(self)
          @output << "|"
        end
        
        if node.body
          @output << ";"
          node.body.accept(self)
        end
        
        @output << "end"
        @in_block = was_in_block
        @needs_semicolon = true
      end

      def visit_parameters_node(node)
        params = []
        params.concat(node.requireds.map { |param| param.name.to_s }) if node.requireds
        params.concat(node.optionals.map { |param| "#{param.name}=#{param.value}" }) if node.optionals
        @output << params.join(",")
      end

      def visit_if_node(node)
        @output << "if "
        node.predicate.accept(self)
        @output << ";"
        node.statements.accept(self)
        if node.consequent
          @output << "else;"
          node.consequent.accept(self)
        end
        @output << "end"
        @needs_semicolon = true
      end

      def visit_while_node(node)
        @output << "while "
        node.predicate.accept(self)
        @output << ";"
        node.statements.accept(self)
        @output << "end"
        @needs_semicolon = true
      end

      def visit_until_node(node)
        @output << "until "
        node.predicate.accept(self)
        @output << ";"
        node.statements.accept(self)
        @output << "end"
        @needs_semicolon = true
      end

      def visit_return_node(node)
        @output << "return"
        if node.arguments
          @output << " "
          node.arguments.accept(self)
        end
      end

      def visit_assignment_node(node)
        node.target.accept(self)
        @output << "="
        node.value.accept(self)
      end

      def visit_operator_assignment_node(node)
        node.target.accept(self)
        @output << node.operator
        node.value.accept(self)
      end

      def visit_instance_variable_write_node(node)
        @output << node.name.to_s
        @output << "="
        node.value.accept(self)
      end

      def visit_instance_variable_read_node(node)
        @output << node.name.to_s
      end

      def visit_array_node(node)
        @output << "["
        node.elements.each_with_index do |element, index|
          @output << "," if index > 0
          element.accept(self)
        end
        @output << "]"
      end

      def visit_hash_node(node)
        @output << "{"
        node.elements.each_with_index do |element, index|
          @output << "," if index > 0
          element.accept(self)
        end
        @output << "}"
      end

      def visit_pair_node(node)
        node.key.accept(self)
        @output << ":"
        node.value.accept(self)
      end

      def visit_symbol_node(node)
        @output << ":"
        @output << node.value.to_s
      end

      def visit_local_variable_read_node(node)
        @output << node.name.to_s
      end

      def visit_local_variable_write_node(node)
        @output << node.name.to_s
        @output << "="
        node.value.accept(self)
      end

      def visit_string_concat_node(node)
        node.left.accept(self)
        node.right.accept(self)
      end

      def visit_interpolated_string_node(node)
        @output << '"'
        node.parts.each do |part|
          if part.is_a?(Prism::StringNode)
            @output << part.content.to_s.gsub("\\", "\\\\").gsub('"', '\\"')
          else
            @output << "\#{"
            part.accept(self)
            @output << "}"
          end
        end
        @output << '"'
        @needs_semicolon = true
      end

      def visit_range_node(node)
        node.left.accept(self)
        @output << ".."
        node.right.accept(self)
      end

      def visit_parentheses_node(node)
        @output << "("
        node.body.accept(self)
        @output << ")"
      end

      def visit_begin_node(node)
        node.statements.accept(self)
      end

      def visit_else_node(node)
        node.statements.accept(self)
      end

      def visit_ensure_node(node)
        node.statements.accept(self)
      end

      def visit_rescue_node(node)
        node.statements.accept(self)
      end
    end
  end
end 
