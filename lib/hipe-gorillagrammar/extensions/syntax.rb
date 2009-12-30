module Hipe::GorillaGrammar
  module GorillaSymbol
    def syntax_pretty_name; @name ? @name.to_s.upcase : nil end
  end

  module RegexpTerminal
    def syntax_tokens; [syntax] end
    def syntax; syntax_pretty_name || self end
  end

  module StringTerminal
    def syntax_tokens; [syntax] end
    def syntax; self end
  end

  class SymbolReference
    def syntax_tokens; [syntax_pretty_name] end
  end

  module NonTerminalSymbol
    def syntax
      return (syntax_tokens * ' ').gsub(%r{(?:[\[\(] +| +[\]\)]| +\| +)}){|x| x.strip}
    end
  end

  class Sequence
    def syntax_tokens
      @group.map{ |x| x.syntax_tokens }.flatten
    end
  end

  class RangeOf
    def syntax_tokens;
      is_one_or_more = (@range == (1..Infinity) and @group.size == 1 and @group[0].kind_of? SymbolReference)
      things = case true
        when (@range == (0..1))        then ['[', nil, ']']
        when (@range == (1..1))        then ['(', nil, ')']
        when (@range == (0..Infinity)) then ['[', '[...]', ']']
        when (is_one_or_more) then ['[', '[...]', ']'] # *special handing below
        else [%{(#{@range.to_s}) of (}, nil, ')']
      end
      thing = @group.map{ |x| x.syntax_tokens }.zip(Array.new(@group.size-1,'|')).flatten.compact
      thing.unshift things[0]
      thing.push things[1] if things[1]
      thing.push things[2]
      thing.unshift @group[0].syntax_pretty_name if is_one_or_more
      thing
    end
  end
end
