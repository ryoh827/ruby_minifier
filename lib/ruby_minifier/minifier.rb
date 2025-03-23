require 'prism'

module RubyMinifier
  class Minifier
    REMOVALS = %i[COMMENT IGNORED_NEWLINE]
    SPACE_AFTER = %i[KEYWORD_DEF KEYWORD_CLASS KEYWORD_MODULE IDENTIFIER CONSTANT KEYWORD_RETURN]
    SPACE_BEFORE = %i[IDENTIFIER CONSTANT]
    NO_SPACE_BEFORE = %i[PARENTHESIS_LEFT COMMA DOT]
    NO_SPACE_AFTER = %i[PARENTHESIS_RIGHT DOT]
    STRING_TOKENS = %i[STRING_BEGIN STRING_CONTENT STRING_END]
    KEYWORDS = %i[KEYWORD_DEF KEYWORD_CLASS KEYWORD_MODULE KEYWORD_RETURN]
    NEED_SEMICOLON_AFTER = %i[CONSTANT INTEGER STRING_END PARENTHESIS_RIGHT]
    NO_SEMICOLON_BEFORE = %i[KEYWORD_END PARENTHESIS_LEFT COMMA DOT PLUS STAR EQUAL STRING_BEGIN]

    # def self.minify_file(path)
    #   code = File.read(path, encoding: Encoding::UTF_8)
    #   new.minify(code)
    # end

    def minify(code)
      tokens = Prism.lex(code).value
      minified = ""
      previous_token = nil
      need_semicolon = false
      in_string = false
      string_content = false
      parentheses_depth = 0
      next_token = nil

      tokens.each_with_index do |token_with_metadata, index|
        token = token_with_metadata[0]
        next if token.nil? || REMOVALS.include?(token.type)

        # Look ahead to next token
        next_token = tokens[index + 1]&.first if index + 1 < tokens.length

        # Add semicolon before certain tokens
        if need_semicolon && 
           !in_string &&
           parentheses_depth == 0 &&
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
        end

        # Track parentheses depth
        if token.type == :PARENTHESIS_LEFT
          parentheses_depth += 1
        elsif token.type == :PARENTHESIS_RIGHT
          parentheses_depth -= 1
          if parentheses_depth == 0 && next_token && !NO_SEMICOLON_BEFORE.include?(next_token.type)
            need_semicolon = true
          end
        end

        # Add space between keywords and identifiers/constants
        if previous_token && 
           KEYWORDS.include?(previous_token.type) &&
           (token.type == :IDENTIFIER || token.type == :CONSTANT) &&
           !in_string
          minified << " "
        end

        minified << token.value

        # Set need_semicolon flag after certain tokens
        need_semicolon = if string_content || parentheses_depth > 0
          false
        else
          case token.type
          when :IDENTIFIER
            next_token && !NO_SEMICOLON_BEFORE.include?(next_token.type) && next_token.type != :STRING_BEGIN
          else
            NEED_SEMICOLON_AFTER.include?(token.type) || token.type == :KEYWORD_END
          end
        end

        previous_token = token
      end

      # Fix operator spacing
      minified.gsub!(/\s*([+*])\s*/, '\1')
      # Fix parentheses and dot operator spacing
      minified.gsub!(/\s*([().])/, '\1')
      # Fix comma spacing
      minified.gsub!(/\s*,\s*/, ',')
      # Fix assignment operator spacing
      minified.gsub!(/\s*=\s*/, '=')
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
      # Remove trailing semicolon and space
      minified.gsub!(/[;\s]+$/, '')

      minified
    end

    private
  end
end
