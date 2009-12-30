require 'rubygems'
#require 'ruby-debug'
require 'singleton'

class Symbol
  def satisfied?; @satisfied; end
  def accepting?; @accepting; end
end
# these are the different states that a parsing node can have
# after it's consumed a token. absurd hack so we can use smiley faces as symbols  (note 2)
# mouth open means "still accepting".  Smiley means "is satisfied".  four permutations
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
    VERSION = '0.0.1beta'
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
      # enables the use of  =~,  |,  (0..1).of .., .., .., and :some_name[/regexp/] in grammars
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
      attr_accessor :name, :root
      alias_method :names, :keys
      def initialize opts
        opts ||= {}
        @name = opts[:name] if opts[:name]
        @with_operator_shorthands = opts.has_key?(:enable_operator_shorthands) ?
          opts[:enable_operator_shorthands] : true
      end
      def == other; self.inspect == other.inspect end #hack
      def define(&block) # should it return grammar or last symbol? grammar. (note 4:)
        Runtime.enable_operator_shorthands if @with_operator_shorthands
        @root = GorillaSymbol.factory instance_eval(&block) # allows anonymous ranges & sequences as grammr
        @root = @root.dereference if @root.instance_of? SymbolReference
        self[@root.name = '__main__'] = @root if (@root.name.nil?)
        self
      end
      def parse tox; @root.parse tox; end
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
        expecting you to say #{RangeOf.join(tree.expecting.uniq,', ',' or ')}.
      EOS
      end
    end
    class UnexpectedInput < ParseFailure;
      def message
        %{sorry, i don't know what you mean by "#{@info[:token]}".  } +
        ((ex = tree.expecting.uniq).size == 0 ? %{i wasn't expecting any more input.} :
        %{i was expecting you to say #{RangeOf.join(ex,', ',' or ')}.})
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
    module ParseTree; def is_error?; false end end
    module GorillaSymbol # @abstract base
      def self.factory obj # maps data structures to symbols. returns same object or new
        case obj
          when GorillaSymbol then obj # this one must stay on top!
          when Array         then Sequence.new(*obj)
                             # note RangeOf is never constructed directly with factory()
          when Symbol        then SymbolReference.new obj
          when String        then obj.extend StringTerminal
          when Regexp        then obj.extend RegexpTerminal
          else
            raise UsageFailure.new %{Can't determine symbol type for "#{obj.inspect}"},:obj=>obj
        end
      end
      def finalize; self; end
      attr_accessor :name
      attr_reader :kleene
      def natural_name; name ? name.to_s.gsub('_',' ') : nil; end
      def fork_for_parse; Marshal.load Marshal.dump(self); end # note 1
      def reinit_for_parse; extend ParseTree end
      def prune! names=[]; a=(names&instance_variables); a.each{ |x| remove_instance_variable x }; a.size end
      def dereference; self; end
    end
    module TerminalSymbol;
      include GorillaSymbol;
      attr_reader :status
      def inspect; [@name ? @name.inspect : nil, super, %{(#{@token ? '.' : '_' })}].compact.join; end
      def pretty_print q
        q.text inspect
        q.group 1,'{','}' do
          instance_variables.sort.each do |n|
            next if instance_variable_get(n).nil?
            q.text %{#{n}=}; q.pp instance_variable_get(n); q.text(';'); q.breakable
          end
        end
      end
      def recurse &block; yield self end
      def tokens; [@token]; end
    end
    module NonTerminalSymbol;
      include GorillaSymbol;
      def [] (i); super(i) ? super(i) : @group[i]; end
      def size; kind_of?(ParseTree) ? super : @group.size; end
      def == other
        kind_of?(ParseTree) ? builtin_equality(other) :
        (other.class == self.class && @name == @name and @group == other.group)
      end
      attr_reader :group
      def _inspect left, right, name = nil
        name = %{:#{@name}} if name.nil? and @name
        [name, left,
          (0..(@group ? @group.size : self.size)-1).map{|i| (self[i] ? self[i] : @group[i]).inspect}.join(', '),
        right ].compact.join
      end
      def pretty_print q
        names = instance_variables.sort{|a,b| (a=='@group') ? -1 : (b=='@group' ? 1 : a<=>b)}
        names.delete_if{|x| instance_variable_get(x).nil?} # it may have been pruned
        q.group 1,'{','}' do
          q.breakable
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
      def status; raise 'no' unless @status; @status end
      def _status=(smiley); raise 'no' unless smiley.kind_of? Symbol; @status = smiley end
      def recurse &block
        sum_like = yield self
        self.each{ |x| if x.respond_to?(:recurse) then sum_like += x.recurse(&block) end }
        sum_like
      end
      def tokens; [] end # for use in a call to recurse e.g. non_terminal.recurse{|x| x.tokens}
    end
    module StringTerminal # this could also be considered a special case of regexp terminal
      include TerminalSymbol
      def match token
        status = if (self==token)
          @token = token
          (:>)
        else
          (:C)
        end
        @status = status
      end
      def expecting; [%{"#{self}"}]; end
    end
    module RegexpTerminal
      include TerminalSymbol
      Grammar.register_shorthand :regexp, self
      def self.construct_from_shorthand name, *args
        args[0].extend self
      end
      def [](capture_offset); @captures[capture_offset]; end
      def expecting; @name ? [natural_name] : [self.inspect]; end
      def match token # cleaned up for note 5 @ 11/27 11:39 am
        @status = if (md = super(token))
          @captures = md.captures if (md.captures.size>0)
          @token = token
          (:>)
        else
          (:C)
        end
      end
    end
    class SymbolReference
      include GorillaSymbol
      def inspect; %{::#{@name}}; end
      def pp q; q.text(inspect); end
      def initialize symbol
        @name = symbol
        @grammar_name = Runtime.current_grammar!.name
      end
      def dereference;
        @actual ||= Runtime.instance.get_grammar(@grammar_name)[@name].fork_for_parse.reinit_for_parse
      end
      def dereference_light
        Runtime.instance.get_grammar(@grammar_name)[@name]
      end
      [:kleene, :expecting, :reinit_for_parse].each do |name|
        define_method(name){ dereference_light.send(name) }
      end
    end
    module CanParse
      def parse tokens
        tree = self.fork_for_parse.reinit_for_parse
        while token = tokens.shift and tree.match(token).accepting?; end
        if (:C) == tree.status or (tokens.size > 0) # xtra
          UnexpectedInput.new :token=>(:C==tree.status ? token : tokens.first), :tree=>tree
        elsif ! tree.status.satisfied?
          UnexpectedEndOfInput.new :tree=>tree
        else
          tree.finalize; #tree.prune!
        end
      end
    end
    class Sequence < Array
      alias_method :builtin_equality, :==
      include CanParse, NonTerminalSymbol, PipeHack
      Grammar.register_shorthand :sequence, self
      def self.construct_from_shorthand(name, *args); self.new(*args); end
      def initialize *args
        @index = 0 # we use this to report expecting whether or not we are a parse
        raise GrammarGrammarException.new "Arguments must be non-zero length" unless args.size > 0
        @group = args.map{|x| GorillaSymbol.factory x }
      end
      def reinit_for_parse;
        super
        @stop_here = @group.size;
        num = @group.reverse.map{|x|
          x.reinit_for_parse
          x.kleene
        }.find_index{|x| x==false || x.nil? } || @group.size
        @satisfied_at = @group.size - num # trailing children that can be zero length affect when we are satisfied.
        @status = (@satisfied_at==@index) ? :D : :O
        self
      end
      def inspect; _inspect '[',']'; end
      def finalize; _advance if @child; self; end
      def prune!; super %w(@group @index @satisfied_at @status @stop_here @kleene) end
      def expecting # cleanup @fixme @todo.  this was some genetic programming
        return [] if self.status == :>
        child = @child || self.last # might be nil if nothing was grabbed
        expecting = []
        if (child) # if we were able to parse at least one token
          if ((index=@index-1) >= 0) # go backwards, reporting expected from any kleene closures
            (index..0).each do
              if (self[index].kleene) # kleeneup to use find_index
                expecting |= self[index].expecting
              end
            end
          end
          expecting += child.expecting unless child.status == :> # report the expecting tokens from the current symbol ()
        end
        index = size
        # index = child ? ( @index + 1 ) : @index # whether or not we got to a token,
        #index = @index
        if ((!child or child.kleene or child.status.satisfied?) and @group and index < @group.size)
          begin # go forward reporting the expecting from any kleene closures
            expecting |= @group[index].expecting
            break unless @group[index].kleene
          end while((index+=1)<@group.size)
        end
        expecting << "an end to the phrase" if (index == @group.size)
        expecting
      end
      def _advance
        # @child.prune! unless @child.kleene #@todo
        self << remove_instance_variable('@child') # child must be :> (if the child was :D we should keep it)
        case (@index += 1)
          when @stop_here     then (:>) # iff we just finished the last child (there is no lookahead note 5)
          when @satisfied_at  then (:D)
          else                     (:O)
        end
      end
      def match token
        while true
          @child ||= @group[@index].dereference; # @group[@index] = nil; save it for prune
          child_prev_status  = @child.status
          child_status       = @child.match token
          self._status = case child_status
            when :> then _advance
            when :O then :O
            when :D then ((@index+1)>=@satisfied_at) ? :D : :O
            when :C
              if (child_prev_status == :D)
                self._status = _advance
                next if @status.accepting?
                :C
              else
                :C
              end
            else; raise GorillaException.new('symbol returned bad status')
          end # case
          break; # break out of infinite loop
        end # infinite loop
        @status
      end # def match
    end # Sequence
    class MoreOneOff
      Grammar.register_shorthand :more, self
      def self.construct_from_shorthand(a,*b); Infinity; end
    end
    class RangeOf < Array
      alias_method :builtin_equality, :==
      include CanParse, NonTerminalSymbol, PipeHack
      [:zero_or_more,:one_or_more,:zero_or_one,:one,:range_of].each do |name|
        Grammar.register_shorthand name, self
      end
      def self.construct_from_shorthand name, *args; self.new name, args; end
      def initialize name, args
        unless args.size > 0
          raise GrammarGrammarException.new "Arguments must be non-zero length"
        end
        @range = name.instance_of?(Range) ? name : case name
          when :zero_or_more  then (0..Infinity)
          when :one_or_more   then (1..Infinity)
          when :zero_or_one   then (0..1)
          when :one           then (1..1)
          when :range_of         then args.shift
          else raise UsageFailure.new(%{invalid name string "#{name}"})
        end
        raise UsageFailure.new("must be range") unless @range.instance_of? Range
        @group = args.map{|x| GorillaSymbol.factory x }
      end
      attr_reader :range
      attr_accessor :is_pipe_hack
      def reinit_for_parse
        super
        @group.each{ |x| x.reinit_for_parse; @unkleene = true unless x.kleene }
        @kleene = @range.begin == 0 || ! @unkleene
        @status = @kleene ? :D : :O
        @frame_prototype = Marshal.dump @group
        _reframe
        self
      end
      def prune!; super %w(@frame @frame_prototype @range @group @kleene @unkleene) end
      def << jobber # for PipeHack. code smell (:note 1)
        if kind_of?(ParseTree) then super jobber
        else; @group << GorillaSymbol.factory(jobber); end
      end
      def expecting; (@frame || @group || []).map{ |x| x.expecting }.flatten end
      def inspect;
        _inspect '(',')',[@name ? %{:#{@name}} : nil , '(', @range.to_s.gsub('..Infinity',' or more'),'):'].compact.join
      end
      def match token
        @status = nil
        statii = Hash.new(){ |h,k| h[k] = [] }
        @frame.each { |symbol| status = symbol.match(token); statii[status] << symbol }
        if statii[:C].size == @frame.size then @status = :C
        else case statii[:>].size
          when 2..Infinity then raise AmbiguousGrammar.new(:parse => self, :children => statii[:>] )
          when 1 then @status = _advance(statii[:>][0])
          when 0 #fallthru
        end end
        # past this point we know that zero are :> and not all are :C, so some must be :O or :D
        if @status.nil?
          @frame.delete_if{ |x| ! x.status.accepting? }
          @status = @frame.select{|x| x.status == :D }.count == @frame.size ? :D : :O
        end
        @status
      end
      def _advance object
        self << object # (object.kleene ? object : object.prune!)
        case size
          when @range.end then        :>
          when @range then  _reframe; :D
          else;             _reframe; :O
        end
      end
      def _reframe; @frame = (Marshal.load @frame_prototype).map{|x| x.kind_of?(SymbolReference) ? x.dereference : x}; end
      # @deprecated -- please see Hipe::Lingual::Array in 'hipe-core', the official home for this is there.
      # @fixme also this is waiting for unparse()
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
# note 1 having grammar nodes as parse tree nodes.  is it code smell?
# note 3 (resolved - we use them now) consider getting rid of unused base classes
# note 5 peeking isn't even used at this point
# note 6 you might use to_s for unparse
# note 7 todo: descention from regexp to string or vice versa,
# note 8 one day we might have set-like RangeOfs that .., note 9 rangeof forks, sequence just inits group
