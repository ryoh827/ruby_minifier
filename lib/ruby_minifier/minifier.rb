require 'prism'

module RubyMinifier
  class Minifier
    REMOVALS = %i[COMMENT IGNORED_NEWLINE]
    SPACE_AFTER = %i[KEYWORD_DEF KEYWORD_CLASS KEYWORD_MODULE IDENTIFIER CONSTANT KEYWORD_RETURN]
    SPACE_BEFORE = %i[IDENTIFIER CONSTANT]
    NO_SPACE_BEFORE = %i[PARENTHESIS_LEFT COMMA DOT]
    NO_SPACE_AFTER = %i[PARENTHESIS_RIGHT DOT]
    STRING_TOKENS = %i[STRING_BEGIN STRING_CONTENT STRING_END]

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

      tokens.each do |token_with_metadata|
        token = token_with_metadata[0]
        next if token.nil? || REMOVALS.include?(token.type)

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

        # Add semicolon before certain tokens
        if need_semicolon && 
           !in_string &&
           ![:KEYWORD_END, :PARENTHESIS_RIGHT, :PARENTHESIS_LEFT, :COMMA, :DOT, :PLUS, :STAR, :EQUAL, :STRING_BEGIN].include?(token.type) &&
           ![:PARENTHESIS_RIGHT, :COMMA, :DOT, :PLUS, :STAR, :STRING_END].include?(previous_token&.type)
          minified << ";"
          need_semicolon = false
        end

        # Add space between keywords and identifiers
        if previous_token && 
           ((previous_token.type == :KEYWORD_DEF && token.type == :IDENTIFIER) ||
            (previous_token.type == :KEYWORD_CLASS && (token.type == :CONSTANT || token.type == :IDENTIFIER)) ||
            (previous_token.type == :KEYWORD_RETURN && token.type == :IDENTIFIER))
          minified << " "
        end

        minified << token.value

        # Set need_semicolon flag after certain tokens
        need_semicolon = if string_content
          false
        else
          case token.type
          when :KEYWORD_END, :STRING_END, :IDENTIFIER, :CONSTANT, :INTEGER, :PARENTHESIS_RIGHT
            true
          else
            false
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
      # Fix string spacing
      minified.gsub!(/\s*'/, "'")
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
      # Remove semicolon in string content
      minified.gsub!(/'([^']*);([^']*)'/, "'\1\2'")
      # Add semicolon after closing parenthesis
      minified.gsub!(/\)(\w)/, ');\\1')
      # Add semicolon before end
      minified.gsub!(/([^\s;])end/, '\1;end')
      # Add semicolon after string literals
      minified.gsub!(/'([^']+)'([^;)\s])/, "'\\1';\\2")
      # Add semicolon after method calls
      minified.gsub!(/\)([^;)\s])/, ');\1')
      # Remove trailing semicolon and space
      minified.gsub!(/[;\s]+$/, '')
      # Fix spacing around semicolons
      minified.gsub!(/\s*;\s*/, ';')
      # Fix end keyword spacing
      minified.gsub!(/([^;])\s+end/, '\1;end')
      # Fix end keyword after expressions
      minified.gsub!(/([+*])\s*end/, '\1;end')
      # Fix consecutive end keywords
      minified.gsub!(/end\s*end/, 'end;end')

      minified
    end

    private
  end
end
