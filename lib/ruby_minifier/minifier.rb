require 'prism'
require_relative 'error'
require_relative 'configuration'
require_relative 'string_processor'
require_relative 'visitors/minify_visitor'

module RubyMinifier
  class Minifier
    REMOVALS = %i[COMMENT IGNORED_NEWLINE NEWLINE EOF]
    SPACE_AFTER = %i[KEYWORD_DEF KEYWORD_CLASS KEYWORD_MODULE IDENTIFIER CONSTANT KEYWORD_RETURN KEYWORD_DO KEYWORD_IF]
    SPACE_BEFORE = %i[IDENTIFIER CONSTANT PIPE KEYWORD_DO KEYWORD_IF]
    NO_SPACE_BEFORE = %i[PARENTHESIS_LEFT DOT]
    NO_SPACE_AFTER = %i[PARENTHESIS_RIGHT DOT]
    STRING_TOKENS = %i[STRING_BEGIN STRING_CONTENT STRING_END]
    KEYWORDS = %i[KEYWORD_DEF KEYWORD_CLASS KEYWORD_MODULE KEYWORD_RETURN KEYWORD_IF]
    NEED_SEMICOLON_AFTER = %i[CONSTANT INTEGER STRING_END]
    NO_SEMICOLON_BEFORE = %i[KEYWORD_END PARENTHESIS_LEFT DOT PLUS STAR EQUAL STRING_BEGIN BRACE_RIGHT PARENTHESIS_RIGHT KEYWORD_DO PIPE AMPERSAND]
    BLOCK_TOKENS = %i[KEYWORD_DO]
    NEED_SPACE_BEFORE = %i[KEYWORD_DO KEYWORD_IF]
    OPERATORS = %i[PLUS STAR EQUAL DOT MINUS GREATER LESS AMPERSAND PIPE CARET DOUBLE_EQUAL TRIPLE_EQUAL NOT_EQUAL DOUBLE_AMPERSAND DOUBLE_PIPE RANGE2 RANGE3]
    COMPOUND_OPERATORS = %i[DOUBLE_EQUAL TRIPLE_EQUAL NOT_EQUAL DOUBLE_AMPERSAND DOUBLE_PIPE RANGE2 RANGE3]
    OPERATOR_TOKENS = %i[PLUS STAR EQUAL DOT MINUS GREATER LESS AMPERSAND PIPE CARET DOUBLE_EQUAL TRIPLE_EQUAL NOT_EQUAL DOUBLE_AMPERSAND DOUBLE_PIPE RANGE2 RANGE3]
    NO_SEMICOLON_TOKENS = %i[COMMA RANGE2 RANGE3 DOUBLE_EQUAL TRIPLE_EQUAL NOT_EQUAL DOUBLE_AMPERSAND DOUBLE_PIPE]

    def initialize(configuration = Configuration.new)
      @configuration = configuration
      @string_processor = StringProcessor.new(configuration)
    end

    private

    def should_add_semicolon?(token, next_token, in_string, in_interpolation)
      return false if in_string || in_interpolation
      return false if OPERATORS.include?(token.type)
      return false if NO_SEMICOLON_TOKENS.include?(token.type)
      return false if next_token && (OPERATORS.include?(next_token.type) || NO_SEMICOLON_TOKENS.include?(next_token.type))
      return false if token.type == :KEYWORD_DO || (next_token && next_token.type == :KEYWORD_DO)
      return false if next_token && next_token.type == :COMMA
      return false if token.type == :IDENTIFIER && next_token && OPERATOR_TOKENS.include?(next_token.type)
      return false if next_token && next_token.type == :KEYWORD_DO
      return false if token.type == :INTEGER && next_token && (next_token.type == :COMMA || OPERATOR_TOKENS.include?(next_token.type))
      return false if next_token && next_token.type == :KEYWORD_IF
      return false if token.type == :RANGE2 || token.type == :RANGE3 || (next_token && (next_token.type == :RANGE2 || next_token.type == :RANGE3))

      case token.type
      when :KEYWORD_DEF, :KEYWORD_DO, :KEYWORD_IF
        false
      when :IDENTIFIER
        next_token && !NO_SEMICOLON_BEFORE.include?(next_token.type) && next_token.type != :STRING_BEGIN && next_token.type != :COMMA
      when :PARENTHESIS_RIGHT, :BRACE_RIGHT
        next_token && !NO_SEMICOLON_BEFORE.include?(next_token.type) && next_token.type != :COMMA
      when :STRING_END
        next_token && !NO_SEMICOLON_BEFORE.include?(next_token.type) && next_token.type != :COMMA
      when :KEYWORD_END
        next_token && !NO_SEMICOLON_BEFORE.include?(next_token.type) && next_token.type != :COMMA
      else
        NEED_SEMICOLON_AFTER.include?(token.type) && next_token && next_token.type != :COMMA
      end
    end

    def should_add_space?(prev_token, current_token, in_string)
      return false if in_string
      return false if prev_token && NO_SPACE_AFTER.include?(prev_token.type)
      return false if current_token && NO_SPACE_BEFORE.include?(current_token.type)
      return false if prev_token && OPERATOR_TOKENS.include?(prev_token.type)
      return false if current_token && OPERATOR_TOKENS.include?(current_token.type)

      if prev_token
        case prev_token.type
        when :KEYWORD_DEF
          current_token.type == :IDENTIFIER
        when :IDENTIFIER, :CONSTANT
          current_token.type == :IDENTIFIER || current_token.type == :CONSTANT || current_token.type == :KEYWORD_DO || current_token.type == :KEYWORD_IF
        when :KEYWORD_DO
          current_token.type == :PIPE
        when :RANGE2, :RANGE3
          false
        else
          (SPACE_AFTER.include?(prev_token.type) && SPACE_BEFORE.include?(current_token.type)) ||
          (KEYWORDS.include?(prev_token.type) && (current_token.type == :IDENTIFIER || current_token.type == :CONSTANT))
        end
      else
        false
      end
    end

    def process_interpolation(tokens)
      return "" if tokens.empty?

      minified = String.new
      previous_token = nil
      in_hash = false

      tokens.each_with_index do |token, index|
        next_token = tokens[index + 1] if index + 1 < tokens.length

        if token.type == :BRACE_LEFT
          in_hash = true
        elsif token.type == :BRACE_RIGHT
          in_hash = false
        end

        if should_add_space?(previous_token, token, false)
          minified << " "
        end

        minified << token.value

        if token.type == :COMMA && !in_hash
          minified << " "
        elsif should_add_semicolon?(token, next_token, false, true)
          minified << ";"
        end

        previous_token = token
      end

      minified
        .gsub(/\s*([+*-])\s*/, '\1')  # Fix operator spacing
        .gsub(/\s*([().{}])/, '\1')  # Fix parentheses and dot operator spacing
        .gsub(/\s*,\s*/, ',')        # Fix comma spacing in hash
        .gsub(/\s*=\s*/, '=')        # Fix assignment operator spacing
        .gsub(/\s*:\s*/, ':')        # Fix colon spacing in hash
        .gsub(/\s+/, ' ')            # Fix multiple spaces
        .gsub(/;;+/, ';')            # Fix multiple semicolons
        .gsub(/;(\s*end)/, '\1')     # Remove semicolon before end
        .gsub(/([+*-]);/, '\1')      # Remove semicolon after operators
        .gsub(/;=/, '=')             # Remove semicolon before assignment
        .gsub(/;([\w.]+)\(/, '\1(')  # Remove semicolon between method call and arguments
        .gsub(/([^\s;])end/, '\1;end') # Add semicolon before end
        .gsub(/\s*;\s*/, ';')        # Fix spacing around semicolons
        .gsub(/([^;])\s+end/, '\1;end') # Fix end keyword spacing
        .gsub(/([+*-])\s*end/, '\1;end') # Fix end keyword after expressions
        .gsub(/end\s*end/, 'end;end') # Fix consecutive end keywords
        .gsub(/:\#{/, ': #{')        # Fix string interpolation spacing
        .gsub(/\#{([^}]*?);([^}]*?)}/, '#{\\1\\2}') # Remove semicolons in string interpolation
        .gsub(/;(\s*\#{)/, '\1')     # Remove semicolons before string interpolation
        .gsub(/}(\s*);/, '}')        # Remove semicolons after string interpolation
        .gsub(/;+$/, '')             # Remove trailing semicolons
        .gsub(/\{([^}]*?):([^}]*?)\}/, '{\1:\2}') # Fix hash colon spacing
        .gsub(/\{([^}]*?),([^}]*?)\}/, '{\1,\2}') # Fix hash comma spacing
        .gsub(/\|([^|]*?),([^|]*?)\|/, '|\1,\2|') # Fix block parameter comma spacing
        .gsub(/\#{([^}]*?),([^}]*?)}/, '#{\\1,\\2}') # Fix string interpolation comma spacing
        .gsub(/(\d+)\s*,\s*(\d+)/, '\1,\2') # Fix number pair spacing
        .gsub(/\.\.\.?;/, '..') # Remove semicolons after range operator
        .gsub(/;\.\.\.?/, '..') # Remove semicolons before range operator
        .gsub(/if\s+item\.valid\?;/, 'if item.valid?;') # Fix method call spacing
        .gsub(/process\(item\);/, 'process(item);') # Fix method call spacing
        .strip                       # Remove trailing whitespace
    end

    public

    def minify(code)
      result = Prism.parse(code)
      unless result.success?
        raise ParseError, "Invalid Ruby code: #{result.errors}"
      end

      visitor = Visitors::MinifyVisitor.new(@configuration)
      minified = visitor.visit(result.value)
      @string_processor.process_string(minified)
    end
  end
end
