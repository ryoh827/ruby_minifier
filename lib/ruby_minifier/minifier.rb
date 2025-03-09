require 'ripper'

module RubyMinifier
  class Minifier
    REMOVALS = [:on_sp, :on_ignored_nl, :on_comment, :on_embdoc_beg, :on_embdoc, :on_embdoc_end]

    def self.minify_file(path)
      code = File.read(path, encoding: Encoding::UTF_8)
      new.minify(code)
    end

    def minify(code)
      tokens = Ripper.lex(code)
      filtered = remove_tokens(tokens)
      assemble_code(filtered)
    end

    private

    def remove_tokens(tokens)
      tokens.reject do |(_pos, type, text, state)|
        if REMOVALS.include?(type)
          true
        else
          type == :on_nl && drop_newline?(state)
        end
      end
    end

    def drop_newline?(lex_state)
      false
    end

    def assemble_code(tokens)
      output = ''.dup
      prev_type = nil
      prev_text = nil

      tokens.each do |(_pos, type, text, state)|
        if type == :on_nl || type == :on_semicolon
          output << ';' unless output.end_with?(';')
          prev_type = nil
          prev_text = nil
          next
        end

        if needs_space?(prev_type, prev_text, type, text)
          output << ' '
        end

        output << text
        prev_type, prev_text = type, text
      end

      output
    end

    def needs_space?(prev_type, prev_text, cur_type, cur_text)
      return false if prev_type.nil?
      prev_word_char = (prev_text =~ /\w|\$/)
      cur_word_char  = (cur_text  =~ /\w|@|\$/)
      if prev_word_char && cur_word_char
        true
      elsif prev_type == :on_kw && cur_word_char
        true
      else
        false
      end
    end
  end
end

