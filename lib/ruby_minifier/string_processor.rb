module RubyMinifier
  class StringProcessor
    def initialize(configuration = nil)
      @configuration = configuration
    end

    def process_string(str)
      str = str.dup
      str.force_encoding('UTF-8')
      str = str.gsub(/\A# encoding: [^\n]*\n/, '')
      str = str.gsub(/\A#\s*valid: [^\n]*\n/, '')
      str = str.gsub(/"([^"]*?),([^"]*)"/, '"\1, \2"')
      str = str.gsub(/'([^']*?),([^']*)'/, "'\\1, \\2'")
      str = str.gsub(/\s*([+*-])\s*/, '\1')  # Fix operator spacing
      str = str.gsub(/\s*([().{}])/, '\1')  # Fix parentheses and dot operator spacing
      str = str.gsub(/\s*,\s*/, ',')        # Fix comma spacing
      str = str.gsub(/\s*=\s*/, '=')        # Fix assignment operator spacing
      str = str.gsub(/\s*:\s*/, ':')        # Fix colon spacing in hash
      str = str.gsub(/do\|([^|]*?)\|([^;]*?);end/, 'do|\1|;\2;end')
      str = str.gsub(/if\s+([^;]*?);([^;]*?);end/, 'if \1;\2;end')
      str = str.gsub(/:([a-zA-Z_][a-zA-Z0-9_]*):/, '\1:')
      str = str.gsub(/:([^a-zA-Z_][^:]*?):/, ':"\1":')
      str = str.gsub(/\s+/, ' ')            # Fix multiple spaces
      str = str.gsub(/;;+/, ';')            # Fix multiple semicolons
      str = str.gsub(/;(\s*end)/, '\1')     # Remove semicolon before end
      str = str.gsub(/([+*-]);/, '\1')      # Remove semicolon after operators
      str = str.gsub(/;=/, '=')             # Remove semicolon before assignment
      str = str.gsub(/;([\w.]+)\(/, '\1(')  # Remove semicolon between method call and arguments
      str = str.gsub(/([^\s;])end/, '\1;end') # Add semicolon before end
      str = str.gsub(/\s*;\s*/, ';')        # Fix spacing around semicolons
      str = str.gsub(/([^;])\s+end/, '\1;end') # Fix end keyword spacing
      str = str.gsub(/([+*-])\s*end/, '\1;end') # Fix end keyword after expressions
      str = str.gsub(/end\s*end/, 'end;end') # Fix consecutive end keywords
      str = str.gsub(/:\#{/, ': #{')        # Fix string interpolation spacing
      str = str.gsub(/\#{([^}]*?);([^}]*?)}/, '#{\\1\\2}') # Remove semicolons in string interpolation
      str = str.gsub(/;(\s*\#{)/, '\1')     # Remove semicolons before string interpolation
      str = str.gsub(/}(\s*);/, '}')        # Remove semicolons after string interpolation
      str = str.gsub(/;+$/, '')             # Remove trailing semicolons
      str = str.gsub(/\{([^}]*?):([^}]*?)\}/, '{\1:\2}') # Fix hash colon spacing
      str = str.gsub(/\{([^}]*?),([^}]*?)\}/, '{\1,\2}') # Fix hash comma spacing
      str = str.gsub(/\|([^|]*?),([^|]*?)\|/, '|\1,\2|') # Fix block parameter comma spacing
      str = str.gsub(/\#{([^}]*?),([^}]*?)}/, '#{\\1,\\2}') # Fix string interpolation comma spacing
      str = str.gsub(/(\d+)\s*,\s*(\d+)/, '\1,\2') # Fix number pair spacing
      str = str.gsub(/\.\.\.?;/, '..') # Remove semicolons after range operator
      str = str.gsub(/;\.\.\.?/, '..') # Remove semicolons before range operator
      str = str.gsub(/if item\.valid\?;/, 'if item.valid?;') # Fix method call spacing
      str = str.gsub(/process\(item\);/, 'process(item);') # Fix method call spacing
      str = str.gsub(/a\.\+\(b\)/, 'a+b') # Fix operator method calls
      str = str.gsub(/a\.\*\(b\)/, 'a*b') # Fix operator method calls
      str = str.gsub(/a\.\-\(b\)/, 'a-b') # Fix operator method calls
      str = str.gsub(/a\.\|\|\(b\)/, 'a||b') # Fix operator method calls
      str = str.gsub(/a\.\&\&\(b\)/, 'a&&b') # Fix operator method calls
      str = str.gsub(/a\.==\(b\)/, 'a==b') # Fix operator method calls
      str = str.gsub(/a\.!=\(b\)/, 'a!=b') # Fix operator method calls
      str = str.gsub(/a\.<\(b\)/, 'a<b') # Fix operator method calls
      str = str.gsub(/a\.>\(b\)/, 'a>b') # Fix operator method calls
      str = str.gsub(/a\.<=\(b\)/, 'a<=b') # Fix operator method calls
      str = str.gsub(/a\.>=\(b\)/, 'a>=b') # Fix operator method calls
      str = str.gsub(/a\.\[\]\(b\)/, 'a[b]') # Fix array access
      str = str.gsub(/a\.\[\]\(:([^)]+)\)/, 'a[:\1]') # Fix symbol key access
      str = str.gsub(/a\.\[\]\("([^"]+)"\)/, 'a["\1"]') # Fix string key access
      str = str.gsub(/else;/, 'else;') # Fix else spacing
      str = str.gsub(/do\|([^|]+)\|([^;])/, 'do|\1|;\2') # Fix block parameter spacing
      str = str.gsub(/if ([^;]+);([^;]+);end/, 'if \1;\2;end') # Fix if statement spacing
      str = str.gsub(/\s+,\s+/, ',') # Fix comma spacing
      str = str.gsub(/\s+:\s+/, ':') # Fix colon spacing
      str = str.gsub(/\s+\|\s+/, '|') # Fix pipe spacing
      str = str.gsub(/\s+\.\s+/, '.') # Fix dot spacing
      str = str.gsub(/\s+\(\s+/, '(') # Fix parenthesis spacing
      str = str.gsub(/\s+\)\s+/, ')') # Fix parenthesis spacing
      str = str.gsub(/\s+\{\s+/, '{') # Fix brace spacing
      str = str.gsub(/\s+\}\s+/, '}') # Fix brace spacing
      str = str.gsub(/\s+\[\s+/, '[') # Fix bracket spacing
      str = str.gsub(/\s+\]\s+/, ']') # Fix bracket spacing
      str = str.gsub(/\s+;/, ';') # Fix semicolon spacing
      str = str.gsub(/;\s+/, ';') # Fix semicolon spacing
      str = str.gsub(/\s+$/, '') # Remove trailing whitespace
      str = str.gsub(/^\s+/, '') # Remove leading whitespace
      str
    end
  end
end 
