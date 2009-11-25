require 'rubygems'
require 'ruby-debug'

module Hipe
  
  def self.GorillaGrammar *args, &block
    GorillaGrammar.make(*args, &block)
  end
  
  module GorillaGrammar
    
    VERSION = '0.0.0'
    
    class GorillaException < Exception; end                  
    class UsageFailure < GorillaException; end    
    class AmbiguousGrammarUsageFailure < UsageFailure; end
    class ParseFailure < GorillaException; end  
    class UnexpectedEndOfInput < ParseFailure; end
    class UnexpectedInput < ParseFailure; end
          
    SATISFIED = 0x01
    ACCEPTING = 0x02
          
    def self.make &block
      self.instance_eval(&block)
    end
          
    @@shorthands = {}      
    def self.add_shorthand name, klass
      @@shorthands[name] = klass
    end
        
    def self.method_missing name, *args
      if @@shorthands[name]
        @@shorthands[name].construct_from_shorthand name, *args
      else
        s = 'available shorthands: ('+@@shorthands.keys.map{|k| k.to_s}.sort * ', '+')'
        raise NoMethodError.new "undefined method #{name} for #{self.inspect}:#{self.class} -- #{s}"
      end
    end
            
    module GorillaSymbol # @abstract base
      module ModuleMethods
        # a module passes this self and a symbol name 
        def register_shorthand_constructor name, klass
          GorillaGrammar.add_shorthand name, klass
        end
      end
    end
    
    module TerminalSymbol # @abstract base
      include GorillaSymbol
    end
    
    module NonTerminalSymbol # @abstract base
      include GorillaSymbol
    end
  
    module StringTerminal
      include TerminalSymbol
      def grammar_description_name
        self
      end
      def match token, peek
        (self == token) ? (SATISFIED & ~ ACCEPTING) : nil
      end      
    end
    
    class PlaceholderTerminal # for Symbol builtin type, can't define singleton - no virtual class
      include TerminalSymbol
      def initialize symbol
        @symbol = symbol
      end
      def grammar_description_name
        @internal.inspect
      end
      def match token, peek
        @match_data = token;
        SATISFIED & ~ACCEPTING
      end
    end    
 
    module RegexpTerminal
      include TerminalSymbol
      extend GorillaSymbol::ModuleMethods
      register_shorthand_constructor :regexp, self
      def self.construct_from_shorthand name, *args
        self.new args
      end
      protected
      def initialize( *args )
        @grammer_description_name = args[0]
        super args[1]
      end
      public
      def match token, peek
        if (md = self.match(token))
          @match_data = md.captures
          SATISFIED & ~ACCEPTING
        else
          nil
        end
      end
    end
    
    module RangeOf
      Infinity = 1.0 / 0
      include NonTerminalSymbol
      extend GorillaSymbol::ModuleMethods      
      register_shorthand_constructor :zero_or_more_of, self      
      register_shorthand_constructor :one_or_more_of, self
      register_shorthand_constructor :zero_or_one_of, self
      def self.construct_from_shorthand name, *args
        RangeOf.new name, *args
      end      
      protected 
      def initialize name, *args
        @range = case name
          when :zero_or_more_of then (0..Infinity)
          when :one_or_more_of then (1..Infinity)
          when :zero_or_one_of then (0..1)
          else raise UsageFailure %{invalid range string "#{name}"}
        end
        @set = args[1]
        @set.extend SymbolSet
      end
    end
    
    # This guy is the one that manages mapping builtin ruby data
    # structures to classes of symbols in our grammar thing.
    module SymbolSet # "bless" an array of symbol ruby structures
      # remember this may be used for both lists and sets
      def self.extend_object array
        array.each_with_index do |obj, i|
          case obj
            when GorillaSymbol then next
            when String        then obj.extend StringTerminal
            when Symbol        then array[i] = PlaceholderTerminal.new(obj) # b/c we can't extend a symbol
            when Regexp        then obj.extend RegexpTerminal
            else UsageFailure.new %{don't know what to do with "#{obj.inspect}"}
          end  
        end
      end # def extend_obj
    end # SymbolSet
    
    module SymbolSequence
      include NonTerminalSymbol
      extend GorillaSymbol::ModuleMethods 
      register_shorthand_constructor :sequence, self

      def self.construct_from_shorthand name, *args
        SymbolSequence.new( *args )
      end
      def initialize *args
        args.extend SymbolSet
      end  
    end
  end
end