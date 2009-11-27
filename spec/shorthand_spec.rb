#rake spec SPEC=spec/shorthand_spec.rb
require 'hipe-gorillagrammar'
include Hipe::GorillaGrammar

describe Hipe::GorillaGrammar, " with shorthands" do

  it "should bark on missing method" do
    lambda {
      Hipe::GorillaGrammar.define {
        bork()
      }
    }.should raise_error(NameError)
  end

  it "every one should construct" do
    a = {}
    Hipe::GorillaGrammar(){                                                            
      a[:ro56] = range_of(         5..6, 'alpha','beta','gamma')      
      a[:ro11] = one_of(           'delta','epsilon')               
      a[:ro01] = zero_or_one_of(   'zeta')                                  
      a[:ro1i] = one_or_more_of(   'eta','theta')                           
      a[:ro0i] = zero_or_more_of(  'iota')                                   
      a[:seq1] = sequence(         'kappa','lambda','mu')             
      a[:rexp] = regexp(           /^.$/)                           
    }                              
      a[:ro56].inspect.should ==   '(5..6):["alpha", "beta", "gamma"]'
      a[:ro11].inspect.should ==   '(1..1):["delta", "epsilon"]'
      a[:ro01].inspect.should ==   '(0..1):["zeta"]'
      a[:ro1i].inspect.should ==   '(1..Infinity):["eta", "theta"]'
      a[:ro0i].inspect.should ==   '(0..Infinity):["iota"]'
      a[:seq1].inspect.should ==   '["kappa", "lambda", "mu"]'
      a[:rexp].inspect.should ==   '/^.$/'
  end

  it "should turn pipe into RangeOf" do
    rangey = nil
    g = Hipe.GorillaGrammar {
      rangey = 'you' | 'i'
    }
    rangey.class.ancestors.include?(RangeOf).should == true
  end

  it "muliple strings with pipe" do
    rangey = nil
    g = Hipe.GorillaGrammar {
      rangey = 'you' | 'i' | 'him'
    }
    rangey.class.ancestors.include?(RangeOf).should == true
  end

  it "should do Fixnum.of" do
    rangey = nil
    g = Hipe.GorillaGrammar {
      rangey = 1.of 'you','i'
    }
    rangey.class.ancestors.include?(RangeOf).should == true
  end

  it "different kind of pipies should be equal " do
    g = Hipe.GorillaGrammar {
      range_of_1 = 1.of 'you','i','he'
      range_of_2 = 'you' | 'i' | 'he'
      range_of_3 = (1..1).of 'you','i','he'
      range_of_4 = range_of 1..1, 'you','i','he'
      range_of_5 = one_of 'you', 'i', 'he'
      target = RangeOf.new(1..1, ['you','i','he'])
      target_str = target.inspect
      target_str.should == %{(1..1):["you", "i", "he"]}
      range_of_1.inspect.should == target_str
      range_of_2.inspect.should == target_str
      range_of_3.inspect.should == target_str
      range_of_4.inspect.should == target_str
      range_of_5.inspect.should == target_str
    }
  end

  it "should complain on bad symbol" do
    lambda {
      Hipe.GorillaGrammar {
        :some_symbol =~ 123
      }
    }.should raise_error(UsageFailure, %{Can't determine symbol type for "123"})
  end

  it "should complain on re-definition" do
    lambda {
      Hipe.GorillaGrammar {
        :symbol =~ ['this']
        :symbol =~ ['this']
      }
    }.should raise_error(UsageFailure, %r{Can't redefine symbols \(symbol\)})
  end

  it "should store symbols" do
    sentence = Hipe.GorillaGrammar(:name=>:grammar1) {
      :subject   =~ 'you'|'i'|'he'|'she'
      :verb      =~ 1.of('run','walk','blah')
      :adverb    =~ 'quickly'|'slowly'|['without', 'hesitation']
      :predicate =~ (0..1).of(:adverb, :verb, :object[/^.*$/])
      :sentence  =~ [:subject,:predicate]
    }
    g = Runtime.get_grammar :grammar1
  end
  
end
