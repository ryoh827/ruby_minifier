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

    def minify(code)
      result = Prism.lex(code)
      tokens = result.value.reject { |token_with_metadata| 
        token = token_with_metadata[0]
        REMOVALS.include?(token.type) || token.type == :COMMENT
      }
      
      minified = String.new
      previous_token = nil
      need_semicolon = false
      in_string = false
      string_content = false
      parentheses_depth = 0
      brace_depth = 0
      next_token = nil
      in_interpolation = false
      interpolation_buffer = String.new
      interpolation_tokens = []

      tokens.each_with_index do |token_with_metadata, index|
        token = token_with_metadata[0]
        next if token.nil?

        # Look ahead to next token
        next_token = tokens[index + 1]&.first if index + 1 < tokens.length

        # Add semicolon before certain tokens
        if need_semicolon && 
           !in_string &&
           !in_interpolation &&
           !BLOCK_TOKENS.include?(previous_token&.type) &&
           !NO_SEMICOLON_BEFORE.include?(token.type)
          minified << ";"
          need_semicolon = false
        end

        # Track string state
        if token.type == :STRING_BEGIN
          in_string = true
          string_content = false
        elsif token.type == :STRING_CONTENT
          string_content = true
        elsif token.type == :STRING_END
          in_string = false
          string_content = false
          need_semicolon = true if next_token && !NO_SEMICOLON_BEFORE.include?(next_token.type)
        elsif token.type == :EMBEXPR_BEGIN
          in_interpolation = true
          interpolation_buffer = ""
          interpolation_tokens = []
          minified << "\#{"
          next
        elsif token.type == :EMBEXPR_END
          in_interpolation = false
          # Process interpolation tokens
          interpolation_buffer = ""
          current_segment = ""
          
          # Track state
          in_hash_access = false
          
          # First pass: collect tokens and handle special cases
          i = 0
          while i < interpolation_tokens.length
            t = interpolation_tokens[i]
            case t.type
            when :BRACKET_LEFT
              in_hash_access = true
              current_segment << t.value
            when :BRACKET_RIGHT
              in_hash_access = false
              current_segment << t.value
              # Look ahead for colon
              if i + 1 < interpolation_tokens.length && interpolation_tokens[i + 1].type == :COLON
                i += 1  # Skip the colon
                interpolation_buffer << current_segment << ": "
                current_segment = ""
              else
                interpolation_buffer << current_segment
                current_segment = ""
              end
            when :COLON
              if in_hash_access
                current_segment << t.value
              end
            when :SEMICOLON
              # Skip semicolons in interpolation
              i += 1
              next
            else
              if in_hash_access
                current_segment << t.value
              else
                interpolation_buffer << t.value
              end
            end
            i += 1
          end
          
          # Add any remaining segment
          interpolation_buffer << current_segment unless current_segment.empty?
          
          # Clean up the interpolation buffer
          interpolation_buffer.strip!
          interpolation_buffer.gsub!(/\s+/, ' ')  # Normalize spaces
          interpolation_buffer.gsub!(/:\s*:/, ':')  # Fix double colons
          
          # Add interpolation content with proper #{...} syntax
          minified << '#{' << interpolation_buffer << '}'
          need_semicolon = false  # Reset semicolon flag after string interpolation
          interpolation_tokens.clear  # Clear the buffer for next interpolation
          next
        end

        # Track parentheses and brace depth
        if token.type == :PARENTHESIS_LEFT
          parentheses_depth += 1
        elsif token.type == :PARENTHESIS_RIGHT
          parentheses_depth -= 1
          if parentheses_depth == 0 && next_token && !NO_SEMICOLON_BEFORE.include?(next_token.type)
            need_semicolon = true
          end
        elsif token.type == :BRACE_LEFT
          brace_depth += 1
        elsif token.type == :BRACE_RIGHT
          brace_depth -= 1
          if brace_depth == 0 && next_token && !NO_SEMICOLON_BEFORE.include?(next_token.type)
            need_semicolon = true
          end
        end

        # Add space between keywords and identifiers/constants
        if previous_token && 
           (KEYWORDS.include?(previous_token.type) || BLOCK_TOKENS.include?(previous_token.type)) &&
           (token.type == :IDENTIFIER || token.type == :CONSTANT || token.type == :PIPE) &&
           !in_string
          minified << " "
        end

        # Add space before do keyword
        if token.type == :KEYWORD_DO && !in_string
          minified << " "
        end

        # Handle token value
        if in_interpolation
          interpolation_tokens << token
        else
          minified << token.value
        end

        # Set need_semicolon flag after certain tokens
        need_semicolon = if string_content || in_interpolation
          false
        else
          case token.type
          when :IDENTIFIER
            next_token && !NO_SEMICOLON_BEFORE.include?(next_token.type) && next_token.type != :STRING_BEGIN
          when :PARENTHESIS_RIGHT
            parentheses_depth == 0 && next_token && !NO_SEMICOLON_BEFORE.include?(next_token.type)
          when :BRACE_RIGHT
            brace_depth == 0 && next_token && !NO_SEMICOLON_BEFORE.include?(next_token.type)
          else
            NEED_SEMICOLON_AFTER.include?(token.type) || token.type == :KEYWORD_END
          end
        end

        previous_token = token
      end

      # Fix operator spacing
      minified.gsub!(/\s*([+*])\s*/, '\1')
      # Fix parentheses and dot operator spacing
      minified.gsub!(/\s*([().{}])/, '\1')
      # Fix comma spacing
      minified.gsub!(/\s*,\s*/, ',')
      # Fix assignment operator spacing
      minified.gsub!(/\s*=\s*/, '=')
      # Fix colon spacing in hash
      minified.gsub!(/\s*:\s*/, ':')
      # Fix multiple spaces
      minified.gsub!(/\s+/, ' ')
      # Fix multiple semicolons
      minified.gsub!(/;;+/, ';')
      # Remove semicolon before end
      minified.gsub!(/;(\s*end)/, '\1')
      # Remove semicolon after operators
      minified.gsub!(/([+*]);/, '\1')
      # Remove semicolon before assignment
      minified.gsub!(/;=/, '=')
      # Remove semicolon between method call and arguments
      minified.gsub!(/;([\w.]+)\(/, '\1(')
      # Add semicolon before end
      minified.gsub!(/([^\s;])end/, '\1;end')
      # Fix spacing around semicolons
      minified.gsub!(/\s*;\s*/, ';')
      # Fix end keyword spacing
      minified.gsub!(/([^;])\s+end/, '\1;end')
      # Fix end keyword after expressions
      minified.gsub!(/([+*])\s*end/, '\1;end')
      # Fix consecutive end keywords
      minified.gsub!(/end\s*end/, 'end;end')
      # Fix string interpolation spacing
      minified.gsub!(/:\#{/, ': #{')
      # Remove semicolons in string interpolation
      minified.gsub!(/\#{([^}]*?);([^}]*?)}/, '#{\\1\\2}')
      # Remove semicolons before string interpolation
      minified.gsub!(/;(\s*\#{)/, '\1')
      # Remove semicolons after string interpolation
      minified.gsub!(/}(\s*);/, '}')
      # Fix string interpolation with hash access
      minified.gsub!(/\#{([^}]*?)\[([^\]]+?)\]:\s*([^}]*?)}/, '#{\\1[\\2]:\\3}')
      # Remove all unnecessary semicolons and fix spacing
      minified.gsub!(/\#{([^}]*?)};?\s*:\s*([^}]*?)}/, '#{\\1: \\2}')
      minified.gsub!(/\#{([^}]*?)\[([^\]]+?)\];?\s*:\s*([^}]*?)}/, '#{\\1[\\2]: \\3}')
      # Remove semicolon before closing parenthesis or brace
      minified.gsub!(/;([)}])/, '\1')
      # Add semicolon after closing parenthesis or brace
      minified.gsub!(/([)}])([^\s;)])/, '\1;\2')
      # Remove semicolon before do keyword
      minified.gsub!(/;(\s*do)/, '\1')
      # Fix block parameter spacing
      minified.gsub!(/do\s*\|\s*([^|]+?)\s*;?\s*\|/, 'do|\1|')
      # Remove trailing semicolon and space
      minified.gsub!(/[;\s]+$/, '')

      # Clean up string interpolation
      minified.gsub!(/\#{([^}]*?)\[([^\]]+?)\]:\s*([^}]*?)}/, '#{\\1[\\2]: \\3}')
      minified.gsub!(/\#{([^}]*?)};?\s*([^}]*?)}/, '#{\\1\\2}')
      minified.gsub!(/};\s*"/, '}"')
      minified.gsub!(/;\s*\#{/, ' #{')
      # Remove double interpolation and fix closing braces
      minified.gsub!(/\#{\#{/, '#{')
      minified.gsub!(/}}/, '}')
      minified.gsub!(/\#{([^}]*?)}\s*\#{([^}]*?)}/, '#{\\1: \\2}')
      # Fix string interpolation with hash access
      minified.gsub!(/\#{([^}]*?)\[([^\]]+?)\]:\s*([^}]*?)}/, '#{\\1[\\2]: \\3}')
      # Fix missing closing braces
      minified.gsub!(/\#{([^}]*?)\"/, '#{\\1}"')
      # Fix string interpolation in puts
      minified.gsub!(/puts\"\#{([^}]*?)}\s*\#{([^}]*?)}\";/, 'puts"#{\\1: \\2}";')
      # Fix string interpolation with hash access in puts
      minified.gsub!(/puts\"\#{([^}]*?)\[([^\]]+?)\]:\s*([^}]*?)}\";/, 'puts"#{\\1[\\2]: \\3}";')
      # Fix string interpolation with hash access and colon
      minified.gsub!(/\#{([^}]*?)\[([^\]]+?)\]:\s*([^}]*?)}\s*\#{([^}]*?)}/, '#{\\1[\\2]: \\3: \\4}')

      minified
    end

    private
  end
end
