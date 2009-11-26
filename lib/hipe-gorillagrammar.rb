require 'rubygems'
require 'ruby-debug'
require 'singleton'

class Symbol 
  def satisfied?; @is_satisfied; end
  def accepting?; @is_accepting; end
  
  # we might regret this
  def =~ (symbol_data)
    Hipe::GorillaGrammar::Runtime.instance.current_grammar.register_symbol self, symbol_data
  end

  alias_method :[], :=~ # allows for e.g. a terminal 'var' like  :first_name[/^.+$/]
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
# mouth open means "still accepting".  Smiley means "is satisfied".

module Hipe
  
  def self.GorillaGrammar *args, &block
    GorillaGrammar.make(*args, &block)
  end
  
  module GorillaGrammar
    
    VERSION = '0.0.0'
    Infinity = 1.0 / 0

    class Runtime # for global-like stuff
      include Singleton      
      def initialize
        @grammar_stack = []
      end
      def grammar_push(grammar)
        raise UsageFailure.new('sorry, no making grammars inside of grammars') if @grammar_stack.size > 0
        @grammar_stack << grammar
      end
      def grammar_pop
        @grammar_stack.pop
      end
      def current_grammar
        raise "no current grammar" unless @grammar_stack.size == 1
        @grammar_stack[0]
      end
    end
    
    class GorillaException < Exception
      def initialize(*args)
        super args.shift if args[0].instance_of? String  
        @info = args.last.instance_of?(Hash) ? args.pop : {}
        @extra = args.count > 0 ? args : []
      end
      def tree; @info[:tree]; end
    end
    class UsageFailure < GorillaException; end
    class GrammarGrammarException < UsageFailure; end    
    class AmbiguousGrammar < GrammarGrammarException; end
    class ParseFailure < GorillaException
      def is_error?; true; end
    end
    class UnexpectedEndOfInput < ParseFailure; 
      def message; <<-EOS.gsub(/^        /,'').gsub("\n",' ')
        sorry, unexpected end of input.  I was
        expecting #{RangeOf.join(tree.expecting,', ',' or ')}.
      EOS
      end
    end
    class UnexpectedInput < ParseFailure; 
      def message; <<-EOS.gsub(/^        /,'').gsub("\n",' ')
        sorry, i don't know what you mean by "#{@info[:token]}".  I was
        expecting #{RangeOf.join(tree.expecting,', ',' or ')}.
      EOS
      end
    end

    def self.make &block
      begin
        Runtime.instance.grammar_push self        
        self.instance_eval(&block)
      ensure
        Runtime.instance.grammar_pop        
      end
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
      def is_error?; false; end
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
        ret
      end
      def to_native
        self.dup
      end
      # def expecting -- return array of objects that respond to to_s
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
      def expecting; [%{"#{self}"}]; end
    end
    
    #:timmy[/^.+$/]
    #
    #class PlaceholderTerminal # for Symbol builtin type, can't define singleton - no virtual class
    #  include TerminalSymbol
    #  def initialize symbol
    #    @symbol = symbol
    #  end
    #  def grammar_description_name
    #    @internal.inspect
    #  end
    #  def match token, peek
    #    @match_data = token;
    #    status = :>
    #    @status = status if peek != false
    #    status
    #  end
    #end    

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
      def expecting; @name ? [@name] : [self.to_s]; end
    end

    module CanParse
      def parse tokens
        tree = self.copy_for_parse
        if tokens.size == 0 # special case -- parsing the empty string
          status = tree.initial_status
        else       
          token = nil 
          tokens.each_with_index do |token, i|
            status = tree.match token, tokens[i+1]
            break unless status.accepting?
          end
        end
        if (status.satisfied?)
          tree
        elsif (status.accepting?)
          UnexpectedEndOfInput.new :tree=>tree
        else
          UnexpectedInput.new :token=>token, :tree=>tree
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
    
    class Sequence < Array
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
        @grammar.extend SymbolSet
      end
      def init_for_parse
        @index = 0
      end
      def _advance
        self << @current_child
        @current_child = nil
        @index += 1
        if @index == @grammar.size
          @grammar = nil
          :>
        else
          :O
        end        
      end
      def expecting
        curr = @grammar[@index]
        ret = curr.expecting
        if curr.kind_of? RangeOf and curr.range.begin == 0 and @index < @grammar.size
          ret |= @grammar[@index+1].expecting
        end
        ret
      end
      def match token, peek
        raise "no peeking yet" if peek == false
        begin
          if (@current_child)
            prev_child_status = @current_child.status
          else          
            @current_child = @grammar[@index].copy_for_parse
            prev_child_status = nil
          end
          child_status = @current_child.match token, peek
          status = case child_status
            when :>
              _advance
            when :C 
              if prev_child_status != :D
                :C
              else
                resp = _advance
                if resp == :>
                  :>
                else  # re-run the token against next child
                  next
                end
              end
            when :O then :O
            when :D 
              (@index==@grammar.size-1) ? :D : :O
          end # case
          break;
        end while true
        @status = status
      end # def match
      
      def initial_status; :O; end       
      def to_native
        self.map do |x|
          x.to_native
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
      public
      attr_reader :range
      def expecting
        @group.map{|x| x.expecting}.flatten
      end
      def init_for_parse
        @frame = {}
        @group.each_with_index do |child, index|
          @frame[index] = { :obj => child.copy_for_parse }
        end
      end
      def match token, peek
        is_peek = (false == peek)
        frame_copy = @frame.dup
        frame_copy.keys.each do |key|
          child = frame_copy[key]
          child[:status] = child[:obj].match token, peek # we have to hold on to status b/c this might be a peek
          frame_copy.delete(key) if :C == child[:status]
        end
        status = nil
        if frame_copy.size == 0
          status = :C
        else
          satisfied_nodes = frame_copy.select{|k,c| c[:obj].status.satisfied?}
          case satisfied_nodes.count
            when 2..Infinity then raise AmbiguousGrammar.new(:parse => self, :children => satisfied_children )
            when 1 then status = _advance(satisfied_nodes[0][1], is_peek)
            when 0 #fallthru
          end
          if status.nil?
            # past this point, we know there are zero satisfied (:> or :D) and zero uninterested (:C), 
            # so everyone should be (:O) which means that's what we are
            status = :O
            unless is_peek              
              @frame = frame_copy
            end
          end
        end
        @status = status unless is_peek
        status
      end
      def _advance satisfied_node, is_peek
        hypothetical_size = self.size + 1        
        self << satisfied_node[:obj] unless is_peek
        case hypothetical_size
          when @range.end then :>
          when @range 
            init_for_parse unless is_peek
            :D
          else 
            init_for_parse unless is_peek
            :O
        end
      end
      def _prune
        @frame.delete_if {|k,v| ! v.status.accepting? }
        :O
      end
      def initial_status
        @range.begin == 0 ? :D : :O
      end
      def to_native
        self.map do |x|
          x.to_native
        end
      end
      
      ## @fixme this is waiting for unparse()
      def self.join list, conj1, conj2, &block
        list.map!(&block) if block
        case list.size
        when 0 then ''
        when 1 then list[0]
        else
          joiners = ['',conj2]
          joiners += Array.new(list.size-2,conj1) if list.size >= 3
          list.zip(joiners.reverse).flatten.join         
        end
      end
    end # RangeOf    
  end
end

# note3 consider getting rid of unused base classes