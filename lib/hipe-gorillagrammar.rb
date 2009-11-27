require 'rubygems'
require 'ruby-debug'
require 'singleton'
class Symbol 
  def satisfied?; @satisfied; end
  def accepting?; @accepting; end
end
:D.instance_variable_set :@satisfied, true  # open mouth happy
:D.instance_variable_set :@accepting, true  
:>.instance_variable_set :@satisfied, true  # closed mouth happy
:>.instance_variable_set :@accepting, false  
:O.instance_variable_set :@satisfied, false # open mouth unhappy
:O.instance_variable_set :@accepting, true 
:C.instance_variable_set :@satisfied, false # closed mouth unhappy
:C.instance_variable_set :@accepting, false  
# absurd hack so we can use smiley faces as symbols  (note 2)
# mouth open means "still accepting".  Smiley means "is satisfied".
module Hipe
  def self.GorillaGrammar opts=nil, &block
    GorillaGrammar.define(opts, &block)
  end
  module GorillaGrammar
    VERSION = '0.0.0'
    Infinity = 1.0 / 0
    def self.define(opts=nil, &block)
      g = Runtime.instance.create_grammar! opts      
      Runtime.instance.push_grammar g      
      begin
        g.define(&block)
      ensure
        Runtime.instance.pop_grammar        
      end
    end
    class Runtime # for global-like stuff
      include Singleton      
      def initialize 
        @grammar_stack = []
        @grammars = {}
      end
      def push_grammar(grammar)
        raise UsageFailure.new('sorry, no making grammars inside of grammars') if @grammar_stack.size > 0
        @grammar_stack << grammar
      end
      def pop_grammar; @grammar_stack.pop; end
      def current_grammar!
        raise UsageFailure.new("no current grammar") unless current_grammar
        current_grammar 
      end
      def current_grammar;  @grammar_stack.last;  end
      def self.method_missing(a,*b)
        return instance.send(a,*b) if instance.respond_to? a
        raise NoMethodError.new %{undefined method `#{a}' for #{inspect}}
      end
      def create_grammar! opts
        opts ||= {}
        raise GorillaException.new("for now we can't reopen grammars") if opts[:name] && @grammars[opts[:name]]
        g = Grammar.new opts
        @grammars[g.name] = g
      end
      def get_grammar name; @grammars[name]; end
      # enables the use of  =~,  ||,  (0..1).of .., .., .., and :some_name[/regexp/] in grammars
      def enable_operator_shorthands
        return if @shorthands_enabled
        Symbol.instance_eval { include SymbolHack, PipeHack }
        String.instance_eval { include PipeHack }
        Fixnum.instance_eval { include FixnumOfHack }
        Range.instance_eval { include RangeOfHack }
        @shorthands_enabled = true     
      end
    end
    class Grammar < Hash
      attr_accessor :name
      def initialize opts
        opts ||= {}
        @name = opts[:name] || %{grammar#{self.object_id}}
        @with_operator_shorthands = opts.has_key?(:enable_operator_shorthands) ?    
          opts[:enable_operator_shorthands] : true
      end
      def define &block # should it return grammar or last symbol? (:note 4)
        Runtime.enable_operator_shorthands if @with_operator_shorthands
        @last_symbol = instance_eval(&block)
        self
      end
      def parse tox; @last_symbol.parse tox; end
      def self.register_shorthand name, klass
        instance_eval { 
          define_method(name) { |*args|
            klass.construct_from_shorthand(name, *args)
          }
        }
      end
      def []= name, symbol
        raise UsageFailure.new(%{Can't redefine symbols (#{name})}) if self[name]
        unless symbol.kind_of? GorillaSymbol
          raise GorillaException.new(%{Expecting GorillaSymbol had #{symbol.inspect}}) 
        end
        super name, symbol
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
      def inspect; message; end # el irbo debuggo 
      def message; <<-EOS.gsub(/^        /,'').gsub("\n",' ')
        sorry, unexpected end of input.  I was
        expecting you to say #{RangeOf.join(tree.expecting,', ',' or ')}.
      EOS
      end
    end
    class UnexpectedInput < ParseFailure;
      def inspect; message; end #just for irb debuggo
      def message; <<-EOS.gsub(/^        /,'').gsub("\n",' ')
        sorry, i don't know what you mean by "#{@info[:token]}".  I was
        expecting you to say #{RangeOf.join(tree.expecting,', ',' or ')}.
      EOS
      end
    end
    module PipeHack
      def |(other)
        if self.instance_of? RangeOf
          raise UsageFailure("no") unless self.pipe_hack
          self << other
          ret = self
        else 
          ret = RangeOf.new((1..1),[self,other])
          ret.pipe_hack = true
        end
        ret
      end
    end
    module FixnumOfHack # note that IRL, this will rarely be used for other than 1
      def of *args
        return RangeOf.new((1..1), args)
      end
    end
    module RangeOfHack
      def of *args
        return RangeOf.new(self, args)
      end
    end
    module SymbolHack
      def =~(symbol_data)
        grammar = Runtime.instance.current_grammar
        return super unless grammar
        grammar[self] = GorillaSymbol.factory symbol_data
      end
      # don' alias_method below with above b/c we want the different error messages
      # functionally equivalent to above but intended to be used inline on the right hand side
      def [] (*symbol_data)
        grammar = Runtime.instance.current_grammar
        return super unless grammar
        grammar[self] = GorillaSymbol.factory(symbol_data.count > 1 ? symbol_data : symbol_data[0])
      end
    end
    module ParseTree; 
      attr_reader :status
      def is_error?; false; end
    end
    module GorillaSymbol # @abstract base
      # This guy is the one that manages mapping a given builtin ruby data structure
      # to a symbol class in our grammar thing. It's sorta like "bless" in "oop" perl
      # @return the original object extended or a new object
      def self.factory obj 
        case obj
          when GorillaSymbol then obj # keep this one first!          
          when Array         then Sequence.new(*obj)  
                             # note RangeOf is never constructed directly with factory()
          when Symbol        then SymbolReference.new obj
          when String        then obj.extend StringTerminal
          when Regexp        then obj.extend RegexpTerminal
          else
            raise UsageFailure.new %{Can't determine symbol type for "#{obj.inspect}"},:obj=>obj
        end  
      end
      def can_be_zero_length; false; end
      attr_accessor :name
      def copy_for_parse # note 1 - we use copies of the symbols *as* parse trees
        ret = Marshal.load(Marshal.dump(self))
        ret.extend ParseTree
        ret.init_for_parse if ret.respond_to? :init_for_parse
        ret
      end
    end
    module TerminalSymbol;  include GorillaSymbol; end # @abstract base
    module NonTerminalSymbol;  include GorillaSymbol; end # @abstract base
    module StringTerminal
      include TerminalSymbol
      include ParseTree
      def match token, peek
        status = (self == token) ? (:>) : (:C)
        @status = status if peek != false
        status
      end
      def expecting; [%{"#{self}"}]; end
    end
    # we tried it as a module but it was acting funny. 
    class SymbolReference
      include GorillaSymbol
      def inspect; %{::#{@name}}; end
      alias_method :to_s, :inspect
      def pp q; q.text to_s; end
      def initialize symbol
        @name = symbol 
        @grammar = Runtime.current_grammar! # hold on to whatever grammar is active when it's defined
        @grammar_name = @grammar.name # maybe for marshal mathering
      end
      def dereference; (@grammar || Runtime.instance.get_grammar(@grammar_name))[@name]; end
      def copy_for_parse; dereference.copy_for_parse; end
      def can_be_zero_length; dereference.can_be_zero_length; end
    end
    module RegexpTerminal
      include TerminalSymbol
      Grammar.register_shorthand :regexp, self
      def self.construct_from_shorthand name, *args
        args[0].extend self
      end
      def init_for_parse; @is_parse = true; end
      def inspect;   @is_parse ? %{/#{@match_data.inspect}/} : super; end
      def [](capture_offset); @match_data[capture_offset]; end
      def expecting; @name ? [@name] : [self.to_s]; end        
      def match token, peek # cleaned up for note 5 @ 11/27 11:39 am
        @status = if (md = super(token)) 
          @match_data = (md.captures.size>0) ? md.captures : md[0]
          (:>)
        else
          (:C)
        end
      end
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
    class Sequence < Array
      include CanParse, NonTerminalSymbol
      Grammar.register_shorthand :sequence, self
      def self.construct_from_shorthand name, *args
        self.new(*args)
      end
      def initialize *args
        @index = 0 # whether or not we are a parse, we might use this to report expecting
        raise GrammarGrammarException.new "Arguments must be non-zero length" unless args.size > 0
        @group = args
        (0..@group.size-1).each do |i|
          @group[i] = GorillaSymbol.factory @group[i]
        end
        num = 0
        (@group.size-1).downto(0){|i| 
          break unless @group[i].can_be_zero_length; 
          num += 1
        }
        @satisfied_at = @group.size - num
      end
      def inspect
        return super if @is_parse
        return %{sequence:#{@group.inspect}}
      end
      def to_s; inspect; end
      def init_for_parse
        #@index = 0
        @is_parse = true
      end
      def _advance
        self << @current
        @current = nil
        @index += 1
        case @index
        when @group.size then @group = nil; :>
        when @satisfied_at then :D
        else :O
        end
      end
      def expecting
        current = @current || @group[@index]
        expecting = current.expecting
        if current.can_be_zero_length and @index < @group.size
          expecting |= @group[@index+1].expecting
        end
        expecting
      end
      def match token, peek
        raise "no peeking yet" if peek == false
        begin
          if (@current)
            prev_child_status = @current.status
          else          
            @current = @group[@index].copy_for_parse
            prev_child_status = nil
          end
          child_status = @current.match token, peek
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
              (@index==@group.size-1) ? :D : :O
            else 
              raise GorillaException.new('symbol returned bad status')
          end # case
          break;
        end while true
        @status = status
      end # def match
      def initial_status; :O; end       
    end # Sequence
    class MoreOneOff
      Grammar.register_shorthand :more, self
      def self.construct_from_shorthand(a,*b); Infinity; end
    end
    class RangeOf < Array
      include CanParse, NonTerminalSymbol, PipeHack
      Grammar.register_shorthand :zero_or_more_of, self
      Grammar.register_shorthand :one_or_more_of, self
      Grammar.register_shorthand :zero_or_one_of, self
      Grammar.register_shorthand :one_of, self
      Grammar.register_shorthand :range_of, self
      def self.construct_from_shorthand name, *args
        self.new name, args
      end
      def can_be_zero_length; @can_be_zero_length; end
      def initialize name, args
        unless args.size > 0
          raise GrammarGrammarException.new "Arguments must be non-zero length" 
        end
        @range = name.instance_of?(Range) ? name : case name
          when :zero_or_more_of then (0..Infinity)
          when :one_or_more_of then (1..Infinity)
          when :zero_or_one_of then (0..1)
          when :one_of then (1..1)
          when :range_of then @range = args.shift
          else raise UsageFailure.new(%{invalid name string "#{name}"})
        end
        raise UsageFailure.new("must be range") unless @range.instance_of? Range
        # blessing the array itself will turn it into a sequence 
        @group = args
        zero_ok = true
        (0..args.size-1).each do |i|
          @group[i] = GorillaSymbol.factory @group[i]
          zero_ok = false unless @group[i].can_be_zero_length
        end
        @can_be_zero_length = (@range.begin == 0 or zero_ok)
      end
      def children; @group; end # for debugging from ir
      def << jobber # for PipeHack. code smell @ note 1
        if @is_parse 
          super jobber
        else  
          @group << GorillaSymbol.factory(jobber)
        end
      end
      attr_reader :range
      attr_accessor :pipe_hack
      def expecting;
        if @frame
          @frame.map{|pair| pair[1][:obj].expecting}.flatten
        else
          @group.map{|x| x.expecting}.flatten; 
        end
      end
      def inspect
        return super if @is_parse
        return %{(#{@range.inspect}):#{@group.inspect}}
      end
      def to_s; inspect; end
      def pretty_print(q)
        if @is_parse; super
        else
          q.group 1, %{(#{range}).of }, '' do
            q.pp @group
          end
        end
      end
      def init_for_parse
        @is_parse = 1
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
      def initial_status; @range.begin == 0 ? :D : :O ; end
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
# note 3 (resolved - we use them now) consider getting rid of unused base classes
# note 5 peeking isn't even used at this point