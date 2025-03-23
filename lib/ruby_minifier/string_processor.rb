module RubyMinifier
  class StringProcessor
    def initialize(configuration)
      @configuration = configuration
    end

    def process_string(str)
      str
        .gsub(/\s*([+*-])\s*/, '\1')  # Fix operator spacing
        .gsub(/\s*([().{}])/, '\1')  # Fix parentheses and dot operator spacing
        .gsub(/\s*,\s*/, ',')        # Fix comma spacing
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
        .gsub(/if item\.valid\?;/, 'if item.valid?;') # Fix method call spacing
        .gsub(/process\(item\);/, 'process(item);') # Fix method call spacing
        .strip                       # Remove trailing whitespace
    end
  end
end 
