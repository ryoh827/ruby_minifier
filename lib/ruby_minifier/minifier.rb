require 'prism'
require_relative 'visitors/minify_visitor'

module RubyMinifier
  class ParseError < StandardError; end

  class Minifier
    def initialize
    end

    def minify(source)
      result = Prism.parse(source)
      if result.failure?
        raise ParseError, "Failed to parse Ruby code"
      end

      visitor = Visitors::MinifyVisitor.new
      visitor.visit(result.value)
    end
  end
end
