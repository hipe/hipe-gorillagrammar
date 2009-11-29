require 'rubygems'
require 'ruby-debug'
require 'singleton'
require 'orderedhash'
class Symbol 
  def satisfied?; @satisfied; end
  def accepting?; @accepting; end
end
# these are the different states that a parsing node can have
# after it's consumed a token. absurd hack so we can use smiley faces as symbols  (note 2)
# mouth open means "still accepting".  Smiley means "is satisfied".
:D.instance_variable_set :@satisfied, true  # open mouth happy
:D.instance_variable_set :@accepting, true 
:>.instance_variable_set :@satisfied, true  # closed mouth happy
:>.instance_variable_set :@accepting, false 
:O.instance_variable_set :@satisfied, false # open mouth unhappy
:O.instance_variable_set :@accepting, true 
:C.instance_variable_set :@satisfied, false # closed mouth unhappy
:C.instance_variable_set :@accepting, false 
module Hipe
  def self.GorillaGrammar opts=nil, &block
    GorillaGrammar.define(opts, &block)
  end
  module GorillaGrammar
    VERSION = '0.0.0'
    Infinity = 1.0 / 0
    def self.define(opts=nil, &block)
      runtime = Runtime.instance
      g = runtime.create_grammar! opts 
      runtime.push_grammar g 
      begin
        g.define(&block)
      ensure
        runtime.pop_grammar 
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
        g = Grammar.new opts 
        g.name = %{grammar#{@grammars.size+1}} unless g.name
        raise GorillaException.new("for now we can't reopen grammars") if @grammars[g.name]
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
      attr_accessor :name, :last_symbol
      alias_method :names, :keys
      def initialize opts 
        opts ||= {}
        @name = opts[:name] if opts[:name]
        @with_operator_shorthands = opts.has_key?(:enable_operator_shorthands) ? 
          opts[:enable_operator_shorthands] : true
      end
      def == other; s1,s2='',''; PP.pp(self,s1); PP.pp(other,s2); return s1==s2; end #hack
      def define &block # should it return grammar or last symbol? grammar. (note 4:)
        Runtime.enable_operator_shorthands if @with_operator_shorthands
        @last_symbol = GorillaSymbol.factory instance_eval(&block) # allows anonymous ranges & sequences as grammr
        @last_symbol = @last_symbol.dereference if @last_symbol.instance_of? SymbolReference
        self[@last_symbol.name = '__main__'] = @last_symbol if (@last_symbol.name.nil?)
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
        raise GrammarGrammarException.new(%{Can't redefine symbols. Multiple definitions for :#{name}}) if self[name]
        unless symbol.kind_of? GorillaSymbol
          raise GorillaException.new(%{Expecting GorillaSymbol had #{symbol.inspect}}) 
        end
        symbol.name = name
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
      def inspect; message; end # just for irb debugo 
    end
    class UnexpectedEndOfInput < ParseFailure; 
      def message; <<-EOS.gsub(/^        /,'').gsub("\n",' ')
        sorry, unexpected end of input.  I was
        expecting you to say #{RangeOf.join(tree.expecting,', ',' or ')}.
      EOS
      end
    end
    class UnexpectedInput < ParseFailure;
      def message; <<-EOS.gsub(/^        /,'').gsub("\n",' ')
        sorry, i don't know what you mean by "#{@info[:token]}".  I was
        expecting you to say #{RangeOf.join(tree.expecting,', ',' or ')}.
      EOS
      end
    end
    module PipeHack
      def |(other)
        if self.instance_of? RangeOf
          raise UsageFailure("no") unless self.is_pipe_hack
          self << other
          ret = self
        else 
          ret = RangeOf.new((1..1),[self,other])
          ret.is_pipe_hack = true
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
      def =~ (symbol_data)
        return super unless ( grammar = Runtime.instance.current_grammar )
        grammar[self] = GorillaSymbol.factory symbol_data
      end
      def [] (*symbol_data)
        return super unless Runtime.instance.current_grammar 
        symbol_data = symbol_data[0] if symbol_data.size == 1
        new_symbol = self.=~(symbol_data)
        return SymbolReference.new self
      end
    end
    module ParseTree; 
      attr_reader :status
      def is_error?; false; end
    end
    module GorillaSymbol # @abstract base
      # @return the original object extended or a new object. maps data structures to symbols
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
      def create_empty_parse_tree # we use copies of the symbols *as* parse trees (note 1:)
        ret = Marshal.load Marshal.dump(self)
        ret.extend ParseTree
        ret.init_for_parse if ret.respond_to? :init_for_parse
        ret
      end
      def prune!
        (%w(@index @satisfied_at @group @status @frame @stop_here) & instance_variables).each{|x|
          instance_variable_set x, nil
        }
        self
      end
    end
    module TerminalSymbol;
      include GorillaSymbol;
      attr_accessor :tree, :consumed_token
      def inspect; [@name ? @name.inspect : nil, super, %{(#{@consumed_token ? '.' : '_' })}].compact.join; end
      def pretty_print q
        q.text inspect
        q.group 1,'{','}' do         
          instance_variables.sort.each do |n|
            next if instance_variable_get(n).nil?
            q.text %{#{n}=}; q.pp instance_variable_get(n); q.text(';'); q.breakable 
          end
        end
      end        
    end
    module NonTerminalSymbol; 
      include GorillaSymbol;
      def [] (i); super(i) ? super(i) : @group[i]; end
      def size; kind_of?(ParseTree) ? super : @group.size; end 
      def == other
        kind_of?(ParseTree) ? builtin_equality(other) : 
        (other.class == self.class && @name == @name and @group == other.group)
      end
      attr_reader :group;
      def _inspect left, right, name = nil
        name = %{:#{@name}} if name.nil? and @name
        [name, left, 
          (0..(@group ? @group.size : self.size)-1).map{|i| (self[i] ? self[i] : @group[i]).inspect}.join(', '),
        right ].compact.join
      end
      def pretty_print q
        names = instance_variables.sort
        names.delete('@group') 
        names.push('@group')
        names.delete_if{|x| instance_variable_get(x).nil?} # it may have been pruned
        q.group 1,'{','}' do 
          # show any non-nil properties of this object
          names.each do |name|
            q.text %{#{name}:}
            q.pp instance_variable_get(name)
            q.breakable
          end
          # show any captured children of this object (if it's parsed something)
          each_with_index do |child, i|
            q.text %{#{i}=>}
            q.pp child
            q.breakable
          end 
        end
      end 
    end
    module StringTerminal # this could also be considered a special case of regexp terminal
      include TerminalSymbol
      def match token, peek
        status = if (self==token) 
          @consumed_token = token
          @tree = token
          (:>)          
        else
          (:C)
        end
        @status = status if peek != false
        status
      end
      def expecting; [%{"#{self}"}]; end
    end
    module RegexpTerminal
      include TerminalSymbol
      Grammar.register_shorthand :regexp, self
      def self.construct_from_shorthand name, *args
        args[0].extend self
      end
      def [](capture_offset); @tree[capture_offset]; end
      def expecting; @name ? [@name] : [self.inspect]; end 
      def match token, peek # cleaned up for note 5 @ 11/27 11:39 am
        @status = if (md = super(token)) 
          @tree = (md.captures.size>0) ? md.captures : md[0]
          @consumed_token = token
          (:>)
        else
          (:C)
        end
      end
    end    
    # we tried it as a module but it was acting funny. 
    class SymbolReference
      include GorillaSymbol
      def inspect; %{::#{@name}}; end
      def pp q; q.text(inspect); end
      def initialize symbol
        @name = symbol 
        @grammar_name = Runtime.current_grammar!.name 
      end
      def dereference; (@grammar || Runtime.instance.get_grammar(@grammar_name))[@name]; end
      [:create_empty_parse_tree, :can_be_zero_length, :expecting].each do |name|
        define_method(name){ dereference.send(name) }
      end      
    end
    module CanParse
      def parse tokens
        tree = self.create_empty_parse_tree
        if tokens.size == 0 # special case -- parsing empty input
          status = tree.initial_status
        else
          token = nil # we want it to be scoped out here so it can be used below
          tokens.each_with_index do |token, i|
            status = tree.match token, tokens[i+1]
            break unless status.accepting?
          end
        end
        if (status.satisfied?)
          tree.prune! # pruning here should not be guaranteed
        elsif (status.accepting?)
          UnexpectedEndOfInput.new :tree=>tree
        else
          UnexpectedInput.new :token=>token, :tree=>tree
        end
      end
    end
    class Sequence < Array
      alias_method :builtin_equality, :==
      include CanParse, NonTerminalSymbol
      Grammar.register_shorthand :sequence, self
      def self.construct_from_shorthand(name, *args); self.new(*args); end 
      def initialize *args
        @index = 0 # we use this to report expecting whether or not we are a parse
        raise GrammarGrammarException.new "Arguments must be non-zero length" unless args.size > 0
        @group = args.map{|x| GorillaSymbol.factory x }
        num = @group.reverse.map{|x| x.can_be_zero_length}.find_index(false) || @group.size
        @satisfied_at = @group.size - num # trailing children that can be zero length affect when we are satisfied.
      end
      # code smells below -- maybe a parse, maybe not (:note 1)
      def initial_status; :O; end 
      def init_for_parse; 
        @stop_here = (@group.size-1);  
      end
      def inspect; _inspect '[',']'; end
      def _advance
        self << @current.prune!
        @current = nil
        case (@index += 1)
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
        while true
          prev_child_status = @current ? @current.status : nil
          @current ||= @group[@index].create_empty_parse_tree
          child_status = @current.match token, peek
          status = case child_status
          when :> then _advance
          when :O then :O              
          when :D then (@index>=@satisfied_at) ? :D : :O                                        
          when :C 
            if prev_child_status != :D then :C
            else
              case _advance
              when :> then :>
              else; next # we are :D or :0 re-run the same token against next child
              end
            end
          else 
            raise GorillaException.new('symbol returned bad status')
          end # case
          break; # break out of infinite loop
        end # infinite loop
        @status = status
      end # def match
    end # Sequence
    class MoreOneOff
      Grammar.register_shorthand :more, self
      def self.construct_from_shorthand(a,*b); Infinity; end
    end
    class RangeOf < Array
      alias_method :builtin_equality, :==
      include CanParse, NonTerminalSymbol, PipeHack
      [:zero_or_more_of,:one_or_more_of,:zero_or_one_of,:one_of,:range_of].each do |name|
        Grammar.register_shorthand name, self
      end
      def self.construct_from_shorthand name, *args; self.new name, args; end
      def initialize name, args
        unless args.size > 0
          raise GrammarGrammarException.new "Arguments must be non-zero length" 
        end
        @range = name.instance_of?(Range) ? name : case name
          when :zero_or_more_of  then (0..Infinity)
          when :one_or_more_of   then (1..Infinity)
          when :zero_or_one_of   then (0..1)
          when :one_of           then (1..1)
          when :range_of         then args.shift
          else raise UsageFailure.new(%{invalid name string "#{name}"})
        end
        raise UsageFailure.new("must be range") unless @range.instance_of? Range
        @group = args.map{|x| GorillaSymbol.factory x }
        @can_be_zero_length = @range.begin == 0 or nil != @group.index{|x| x.can_be_zero_length}
      end
      def initial_status; @range.begin == 0 ? :D : :O ; end            
      attr_reader :range
      attr_accessor :is_pipe_hack      
      def can_be_zero_length; @can_be_zero_length; end 
      def << jobber # for PipeHack. code smell (:note 1)
        if    kind_of?(ParseTree) then super jobber
        else; @group << GorillaSymbol.factory(jobber); end
      end
      def expecting;
        if @frame
          @frame.map{|pair| pair[1][:obj].expecting}.flatten
        else
          @group.map{|x| x.expecting}.flatten; 
        end
      end
      def inspect; 
        _inspect '(',')',[@name ? %{:#{@name}} : nil , '(', @range.to_s.gsub('..Infinity',' or more'),'):'].compact.join
      end
      def init_for_parse
        @frame = {}
        @group.each_with_index do |child, index|
          @frame[index] = { :obj => child.create_empty_parse_tree }
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
          satisfied_nodes = frame_copy.select{|k,c| 
            c[:obj].status.satisfied?
          }
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
        satisfied_node[:obj].prune!
        case hypothetical_size
          when @range.end then :>
          when @range then init_for_parse unless is_peek; :D
          else; init_for_parse unless is_peek; :O
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
# note 3 (resolved - we use them now) consider getting rid of unused base classes
# note 5 peeking isn't even used at this point
# note 6 you might use to_s for unparse