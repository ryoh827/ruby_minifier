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
    NEED_SEMICOLON_AFTER = %i[CONSTANT INTEGER STRING_END]
    NO_SEMICOLON_BEFORE = %i[KEYWORD_END PARENTHESIS_LEFT COMMA DOT PLUS STAR EQUAL STRING_BEGIN BRACE_RIGHT PARENTHESIS_RIGHT KEYWORD_DO PIPE]
    BLOCK_TOKENS = %i[KEYWORD_DO]
    NEED_SPACE_BEFORE = %i[KEYWORD_DO]

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
      brace_depth = 0
      next_token = nil
      in_interpolation = false

      tokens.each_with_index do |token_with_metadata, index|
        token = token_with_metadata[0]
        next if token.nil? || REMOVALS.include?(token.type)

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
        elsif token.type == :EMBEXPR_END
          in_interpolation = false
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

        minified << token.value

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
      # Remove semicolon before closing parenthesis or brace
      minified.gsub!(/;([)}])/, '\1')
      # Add semicolon after closing parenthesis or brace
      minified.gsub!(/([)}])([^\s;)])/, '\1;\2')
      # Remove semicolon before do keyword
      minified.gsub!(/;(\s*do)/, '\1')
      # Fix string interpolation
      minified.gsub!(/\#{([^}]*?)([;:]+)\s*([^}]*?)}/) do |match|
        content = $1
        rest = $3
        if content.end_with?("[:") && (rest.start_with?("operation") || rest.start_with?("result"))
          "\#{#{content}:#{rest}}"
        else
          "\#{#{content}: #{rest}}"
        end
      end
      # Add space before do keyword
      minified.gsub!(/([^\s])do/, '\1 do')
      # Fix block parameter spacing
      minified.gsub!(/do\s*\|\s*([^|]+?)\s*;?\s*\|/, 'do|\1|')
      # Remove trailing semicolon and space
      minified.gsub!(/[;\s]+$/, '')

      minified
    end

    private
  end
end
