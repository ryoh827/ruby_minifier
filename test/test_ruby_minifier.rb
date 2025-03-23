# frozen_string_literal: true

require "test_helper"
require 'ruby_minifier'

class TestRubyMinifier < Minitest::Test
  def setup
    @minifier = RubyMinifier::Minifier.new
  end

  def test_that_it_has_a_version_number
    refute_nil ::RubyMinifier::VERSION
  end

  def test_token_structure
    code = "puts 'hello'"
    result = Prism.lex(code)
    tokens = result.value

    assert_equal 5, tokens.length
    assert_equal :IDENTIFIER, tokens[0][0].type
    assert_equal "puts", tokens[0][0].value
  end

  def test_basic_minification
    code = "def hello\n  puts 'world'\nend"
    expected = "\"def hello;puts'world';end\""
    assert_equal expected, @minifier.minify(code)
  end

  def test_comment_removal
    code = "# This is a comment\ndef hello # inline comment\n  puts 'world' # another comment\nend\n"
    expected = "\"def hello;puts'world';end\""
    assert_equal expected, @minifier.minify(code)
  end

  def test_whitespace_optimization
    code = "def  calculate(x,   y)\n  \n  result   =  x  +  y\n\n  return    result\nend\n"
    expected = "\"def calculate(x,y);result=x+y;return result;end\""
    assert_equal expected, @minifier.minify(code)
  end

  def test_complex_code_minification
    code = <<~RUBY
      class Calculator
        def add(a, b)  # 足し算
          a + b        # 結果を返す
        end

        def multiply(a, b)
          # 掛け算を実行
          a * b
        end
      end

      calc = Calculator.new
      result = calc.add(2, 3)      # 2 + 3
      result2 = calc.multiply(4, 5) # 4 * 5
    RUBY

    expected = "\"class Calculator;def add(a,b);a+b;end;def multiply(a,b);a*b;end;end;calc=Calculator.new;result=calc.add(2,3);result2=calc.multiply(4,5)\""
    assert_equal expected, @minifier.minify(code)
  end

  private

  def capture_output
    original_stdout = $stdout
    output = StringIO.new
    $stdout = output
    yield
    output.string
  ensure
    $stdout = original_stdout
  end
end
