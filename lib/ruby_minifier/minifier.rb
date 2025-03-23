require 'prism'

module RubyMinifier
  class Minifier
    REMOVALS = %i[COMMENT IGNORED_NEWLINE NEWLINE EOF]
    SPACE_AFTER = %i[KEYWORD_DEF KEYWORD_CLASS KEYWORD_MODULE IDENTIFIER CONSTANT KEYWORD_RETURN]
    SPACE_BEFORE = %i[IDENTIFIER CONSTANT]
    NO_SPACE_BEFORE = %i[PARENTHESIS_LEFT COMMA DOT]
    NO_SPACE_AFTER = %i[PARENTHESIS_RIGHT DOT]
    STRING_TOKENS = %i[STRING_BEGIN STRING_CONTENT STRING_END]
    KEYWORDS = %i[KEYWORD_DEF KEYWORD_CLASS KEYWORD_MODULE KEYWORD_RETURN]
    NEED_SEMICOLON_AFTER = %i[CONSTANT INTEGER STRING_END]
    NO_SEMICOLON_BEFORE = %i[KEYWORD_END PARENTHESIS_LEFT COMMA DOT PLUS STAR EQUAL STRING_BEGIN BRACE_RIGHT PARENTHESIS_RIGHT KEYWORD_DO PIPE]
    BLOCK_TOKENS = %i[KEYWORD_DO]
    NEED_SPACE_BEFORE = %i[KEYWORD_DO]

    def initialize
      # Prismは初期化不要
    end

    private

    def process_interpolation(tokens)
      result = String.new
      current_segment = String.new
      in_hash_access = false
      hash_key = false

      tokens.each do |token|
        case token.type
        when :BRACKET_LEFT
          in_hash_access = true
          current_segment << token.value
        when :BRACKET_RIGHT
          in_hash_access = false
          current_segment << token.value
          result << current_segment
          current_segment = String.new
        when :COLON
          if in_hash_access
            current_segment << token.value
          else
            hash_key = true
            result << ": "
          end
        when :SEMICOLON
          next
        else
          if in_hash_access
            current_segment << token.value
          else
            if hash_key
              result << token.value
              hash_key = false
            else
              result << token.value
            end
          end
        end
      end

      result.strip.gsub(/\s+/, ' ')
    end

    def should_add_semicolon?(token, next_token, in_string, in_interpolation)
      return false if in_string || in_interpolation

      case token.type
      when :IDENTIFIER
        next_token && !NO_SEMICOLON_BEFORE.include?(next_token.type) && next_token.type != :STRING_BEGIN
      when :PARENTHESIS_RIGHT, :BRACE_RIGHT
        next_token && !NO_SEMICOLON_BEFORE.include?(next_token.type)
      else
        NEED_SEMICOLON_AFTER.include?(token.type) || token.type == :KEYWORD_END
      end
    end

    def should_add_space?(prev_token, current_token, in_string)
      return false if in_string

      if prev_token
        (SPACE_AFTER.include?(prev_token.type) && SPACE_BEFORE.include?(current_token.type)) ||
        (KEYWORDS.include?(prev_token.type) && (current_token.type == :IDENTIFIER || current_token.type == :CONSTANT)) ||
        (BLOCK_TOKENS.include?(prev_token.type) && current_token.type == :PIPE)
      else
        false
      end
    end

    public

    def minify(code)
      result = Prism.lex(code)
      tokens = result.value.reject { |token_with_metadata| 
        token = token_with_metadata[0]
        REMOVALS.include?(token.type) || token.type == :COMMENT
      }
      
      minified = String.new
      previous_token = nil
      in_string = false
      in_interpolation = false
      interpolation_tokens = []

      tokens.each_with_index do |token_with_metadata, index|
        token = token_with_metadata[0]
        next if token.nil?

        next_token = tokens[index + 1]&.first if index + 1 < tokens.length

        # Handle string interpolation
        if token.type == :EMBEXPR_BEGIN
          in_interpolation = true
          interpolation_tokens = []
          minified << "\#{"
          next
        elsif token.type == :EMBEXPR_END
          in_interpolation = false
          minified << process_interpolation(interpolation_tokens) << "}"
          next
        end

        # Handle string state
        if token.type == :STRING_BEGIN
          in_string = true
        elsif token.type == :STRING_END
          in_string = false
        end

        # Add semicolon if needed
        if should_add_semicolon?(token, next_token, in_string, in_interpolation)
          minified << ";"
        end

        # Add space if needed
        if should_add_space?(previous_token, token, in_string)
          minified << " "
        end

        # Handle token value
        if in_interpolation
          interpolation_tokens << token
        else
          minified << token.value
        end

        previous_token = token
      end

      # Clean up the result
      minified
        .gsub(/\s*([+*])\s*/, '\1')  # Fix operator spacing
        .gsub(/\s*([().{}])/, '\1')  # Fix parentheses and dot operator spacing
        .gsub(/\s*,\s*/, ',')        # Fix comma spacing
        .gsub(/\s*=\s*/, '=')        # Fix assignment operator spacing
        .gsub(/\s*:\s*/, ':')        # Fix colon spacing in hash
        .gsub(/\s+/, ' ')            # Fix multiple spaces
        .gsub(/;;+/, ';')            # Fix multiple semicolons
        .gsub(/;(\s*end)/, '\1')     # Remove semicolon before end
        .gsub(/([+*]);/, '\1')       # Remove semicolon after operators
        .gsub(/;=/, '=')             # Remove semicolon before assignment
        .gsub(/;([\w.]+)\(/, '\1(')  # Remove semicolon between method call and arguments
        .gsub(/([^\s;])end/, '\1;end') # Add semicolon before end
        .gsub(/\s*;\s*/, ';')        # Fix spacing around semicolons
        .gsub(/([^;])\s+end/, '\1;end') # Fix end keyword spacing
        .gsub(/([+*])\s*end/, '\1;end') # Fix end keyword after expressions
        .gsub(/end\s*end/, 'end;end') # Fix consecutive end keywords
        .gsub(/:\#{/, ': #{')        # Fix string interpolation spacing
        .gsub(/\#{([^}]*?);([^}]*?)}/, '#{\\1\\2}') # Remove semicolons in string interpolation
        .gsub(/;(\s*\#{)/, '\1')     # Remove semicolons before string interpolation
        .gsub(/}(\s*);/, '}')        # Remove semicolons after string interpolation
        .strip                       # Remove trailing whitespace
    end
  end
end
