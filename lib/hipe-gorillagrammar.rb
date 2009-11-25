require 'rubygems'
require 'ruby-debug'

class Symbol 
  def satisfied?; @is_satisfied; end
  def accepting?; @is_accepting; end
end

:D.instance_variable_set :@is_satisfied, true 
:D.instance_variable_set :@is_accepting, true  
:>.instance_variable_set :@is_satisfied, true 
:>.instance_variable_set :@is_accepting, false  
:O.instance_variable_set :@is_satisfied, false 
:O.instance_variable_set :@is_accepting, true 
:C.instance_variable_set :@is_satisfied, false 
:C.instance_variable_set :@is_accepting, false  
# absurd hack so we can use smiley faces as symbols  (note 2)


module Hipe
  
  def self.GorillaGrammar *args, &block
    GorillaGrammar.make(*args, &block)
  end
  
  module GorillaGrammar
    
    VERSION = '0.0.0'
    Infinity = 1.0 / 0          
    
    class GorillaException < Exception
      def initialize(*args)
        super args[0]
      end
    end
    class UsageFailure < GorillaException; end
    class GrammarGrammarException < UsageFailure; end    
    class AmbiguousGrammar < GrammarGrammarException; end
    class ParseFailure < GorillaException; 
      def initialize args
        
      end
    end
    class UnexpectedEndOfInput < ParseFailure; end
    class UnexpectedInput < ParseFailure; end
                    
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
           
    module ParseTree; 
      attr_reader :status
    end
            
    module GorillaSymbol # @abstract base
      module ModuleMethods
        # a module passes this self and a symbol name 
        def register_shorthand_constructor name, klass
          GorillaGrammar.add_shorthand name, klass
        end
      end
      
      # note 1 - we use copies of the symbols *as* parse trees
      def copy_for_parse
        ret = Marshal.load(Marshal.dump(self))
        ret.extend ParseTree
        ret.init_for_parse if ret.respond_to? :init_for_parse
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
        status = (self == token) ? (:>) : (:C)
        @status = status if peek != false
        status
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
        status = :>
        @status = status if peek != false
        status
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
        status = if (md = self.match(token))
          @match_data = md.captures if peek != false
          (:>)
        else
          (:C)
        end
        @status = status if peek != false
        status
      end
    end

    module CanParse
      def parse tokens
        tree = self.copy_for_parse
        if tokens.size == 0 # special case -- parsing the empty string
          status = tree.initial_status
        else        
          tokens.each_with_index do |token, i|
            status = tree.match token, token[i+1]
            break unless status.accepting?
          end
        end
        if (status.satisfied?)
          tree
        elsif (status.accepting?)
          UnexpectedEndOfInput.new :tree=>@tree
        else
          UnexpectedInput.new :token=>token, :tree=>@tree
        end
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
    
    module Sequence < array
      include CanParse
      include NonTerminalSymbol
      extend GorillaSymbol::ModuleMethods 
      register_shorthand_constructor :sequence, self

      def self.construct_from_shorthand name, *args
        self.new name, *args
      end
      def initialize name, *args
        raise GrammarGrammarException.new "Arguments must be non-zero length" unless args.size > 0
        @grammar = args
        self.extend SymbolSet
      end
      def init_for_parse
        @index = 0
      end
      def parse token, peek
        @current_child = @grammar[@index].copy_for_parse unless @current_child
        status = @current_child.match token, peek
        case status
          when :C then :C
          when :O then :O
          when :> 
            if peek != false              
              self << @current_child
              @current_child = nil
              next_index = (@index += 1)
            else
              next_index = @index + 1
            end
            if (next_index < @grammar.size 
              :O
            else
              @grammar = nil if peek != false
              :>
            end
          when :D
            if peek == false
              if (@index==@grammar.size-1) then :D
              else :O
            else            
              next_response = @current_child.match peek, false
              case next_response
            
      end
    end
      
    end # Sequence

    class RangeOf < Array
      include NonTerminalSymbol
      extend GorillaSymbol::ModuleMethods
      include CanParse  
      register_shorthand_constructor :zero_or_more_of, self      
      register_shorthand_constructor :one_or_more_of, self
      register_shorthand_constructor :zero_or_one_of, self
      register_shorthand_constructor :one_of, self      
      
      def self.construct_from_shorthand name, *args
        new name, *args
      end      
      protected 
      def initialize name, *args
        raise GrammarGrammarException.new "Arguments must be non-zero length" unless args.size > 0
        @range = case name
          when :zero_or_more_of then (0..Infinity)
          when :one_or_more_of then (1..Infinity)
          when :zero_or_one_of then (0..1)
          when :one_of then (1..1)
          else raise UsageFailure %{invalid range string "#{name}"}
        end
        @group = args
        @group.extend SymbolSet
      end
      
      def init_for_parse
        @frame = {}
        @group.each_with_index do |child, index|
          @frame[index] = child.copy_for_parse
        end
      end
      
     # def match token, peek
     #   @frame.each do |child|
     #     child.match token, peek
     #   end
     #   @frame.delete_if{ |key, child| child.status == :C }
     #   done = false
     #   if @frame.size == 0
     #     done = true
     #   else
     #     satisfied = @frame.search{|c| c.status.satisfied?}
     #     case satisfied.count
     #       when 2..Infinity then raise AmbiguousGrammar.new(:parse => self, :children => satisfied_children )
     #       when
     #     if satisfied.count
     #     if (satisfied.count==1)
     #       
     #     
     #     
     #   elsif 
     #   
     #   
     # end
      
      def initial_status
        @range.begin == 0 ? :D : :O
      end

      
    end # RangeOf    
  end
end