#rake spec SPEC=spec/shorthand_spec.rb
require File.dirname(__FILE__)+'/helpers.rb'
require 'hipe-gorillagrammar'
include Hipe::GorillaGrammar

class Grammar
  include Helpers
 # only for irb -- tokenize a string thru the shell.  careful!
  def parz str;
    tox = shell!(str);
    puts "your tokens tokenized from shell:"
    pp tox
    parse tox
  end
end

describe Hipe::GorillaGrammar, " in the context of Shorthands" do
  it "should bark on missing method" do
    lambda {
      Hipe::GorillaGrammar.define {
        bork()
      }
    }.should raise_error(NameError)
  end

  it "should bark when undefined rangeof method (h1)" do
    Grammar.register_shorthand :nonexistant_method, RangeOf
    lambda{
      Hipe.GorillaGrammar{ nonexistant_method('x') }
    }.should raise_error(UsageFailure, /invalid name str/)
  end


  it "every one should construct (h2)" do
    a = {}
    Hipe::GorillaGrammar(){
      a[:ro56] = range_of(         5..6, 'alpha','beta','gamma')
      a[:ro11] = one(           'delta','epsilon')
      a[:ro01] = zero_or_one(   'zeta')
      a[:ro1i] = one_or_more(   'eta','theta')
      a[:ro0i] = zero_or_more(  'iota')
      a[:seq1] = sequence(         'kappa','lambda','mu')
      a[:rexp] = regexp(           /^.$/)
    }
    a[:ro56].group.should ==   ["alpha","beta","gamma"]
    a[:ro56].range.should == (5..6)
    a[:ro11].group.should ==   ["delta","epsilon"]
    a[:ro11].range.should == (1..1)
    a[:ro01].group.should ==   ['zeta']
    a[:ro01].range.should == (0..1)
    a[:ro1i].group.should ==   ['eta','theta']
    a[:ro1i].range.should == (1..Infinity)
    a[:ro0i].group.should ==   ['iota']
    a[:ro01].range.should == (0..1)
    a[:seq1].group.should ==   ['kappa','lambda','mu']
    a[:rexp].should ==   /^.$/
  end

  it "should turn pipe into RangeOf (h3)" do
    rangey = nil
    g = Hipe.GorillaGrammar {
      rangey = 'you' | 'i'
    }
    rangey.class.ancestors.include?(RangeOf).should == true
  end

  it "muliple strings with pipe (h4)" do
    rangey = nil
    g = Hipe.GorillaGrammar {
      rangey = 'you' | 'i' | 'him'
    }
    rangey.class.ancestors.include?(RangeOf).should == true
  end

  it "should do Fixnum.of (h5)" do
    rangey = nil
    g = Hipe.GorillaGrammar {
      rangey = 1.of 'you','i'
    }
    rangey.class.ancestors.include?(RangeOf).should == true
  end

  it "different kind of pipies should be equal (h6)" do
    range_of_1=range_of_2=range_of_3=range_of_4=range_of_5=target=nil
    g = Hipe.GorillaGrammar {
      range_of_1 = 1.of 'you','i','he'
      range_of_2 = 'you' | 'i' | 'he'
      range_of_3 = (1..1).of 'you','i','he'
      range_of_4 = range_of 1..1, 'you','i','he'
      range_of_5 = one 'you', 'i', 'he'
      :main =~ ['']
    }
    target = RangeOf.new(1..1, ['you','i','he'])
    target_str = target.inspect
    target_str.should match(/.{11}/)
    range_of_1.inspect.should == target_str
    range_of_2.inspect.should == target_str
    range_of_3.inspect.should == target_str
    range_of_4.inspect.should == target_str
    range_of_5.inspect.should == target_str
  end

  it "should complain on bad symbol (h7)" do
    lambda {
      Hipe.GorillaGrammar {
        :some_symbol =~ 123
      }
    }.should raise_error(UsageFailure, %{Can't determine symbol type for "123"})
  end

  it "should complain on re-definition (h8)" do
    lambda {
      Hipe.GorillaGrammar {
        :symbol =~ ['this']
        :symbol =~ ['this']
      }
    }.should raise_error(GrammarGrammarException, %r{can't redefine symbol}i)
  end

  it "two ways one grammar (h9)" do
    g = Hipe.GorillaGrammar(:name =>:beuford) { :x =~ '.' }
    Runtime.get_grammar(:beuford).should equal(g)
  end

  it "should store symbols (h10)" do
    g = Hipe.GorillaGrammar(:name=>:grammar1) {
      :subject   =~ 'you'|'i'|'he'|'she'
      :verb      =~ 1.of('run','walk','blah')
      :adverb    =~ 'quickly'|'slowly'|['without', 'hesitation']
      :predicate =~ (0..1).of(:adverb, :verb, :object[/^.*$/])
      :sentence  =~ [:subject,:predicate]
    }
    g[:subject   ].inspect.should match /1.*1.*you.*i.*he.*she/
    g[:verb      ].inspect.should match /1.*1.*run.*walk.*blah/
    g[:adverb    ].inspect.should match /1.*1.*quickly.*slowly.*without.*hesitation/
    g[:predicate ].inspect.should match /0.*1.*adverb.*verb.*object/
    g[:sentence  ].inspect.should match /subject.*predicate/
  end

  it "should work with symbol references (h11)" do
    g = Hipe.GorillaGrammar(:name=>:grammar2) {
      :alpha  =~ 'a'
      :beta   =~ 'b'
      :gamma  =~ 'c'
      :sentence  =~ [:alpha,:beta,:gamma]
    }
    result = g.parse ['a','b','c']
    result.is_error?.should == false
  end

  it "should report expecting right at the start of a branch (h12)" do
    g = Hipe.GorillaGrammar {
      :sentence =~ [
        'i','want','my',
         :manufacturer[1.of(['jimmy','dean'],['hickory','farms'])],
      'sausage' ]
    }
    thing = g.parse ['i','want','my']
    thing.is_error?.should == true
    thing.should be_kind_of UnexpectedEndOfInput
    thing.tree.expecting.should == %w("jimmy" "hickory")  # strings with quotes in them
  end

  it "parse sequence 1 branch 2 x 2 x 1 (h13)" do
    g = Hipe.GorillaGrammar {
      :sentence =~ [:manufacturer[ one %w(jimmy dean), %w(hickory farms) ] ]
    }
    thing = g.parse []
    thing.is_error?.should == true
    thing.should be_kind_of UnexpectedEndOfInput
    thing.tree.expecting.should == %w("jimmy" "hickory")
  end

  it "parse sequence 2 branch 2 x 2 x 1 (h14)" do
    g = Hipe.GorillaGrammar {
      :sentence =~ ['want','jimmy']
    }
    thing = g.parse ['want']
    thing.is_error?.should == true
    thing.should be_kind_of UnexpectedEndOfInput
    thing.tree.expecting.should == %w("jimmy")
  end

  # h15 moved to another file (parsing)

end
