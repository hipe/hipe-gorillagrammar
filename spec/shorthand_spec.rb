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
      a[:seq1].inspect.should ==   'sequence:["kappa", "lambda", "mu"]'
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

  it "two ways one grammar" do
    g = Hipe.GorillaGrammar(:name =>:beuford) { :x =~ '.' }
    Runtime.get_grammar(:beuford).should equal(g)
  end

  it "should store symbols" do
    g = Hipe.GorillaGrammar(:name=>:grammar1) {
      :subject   =~ 'you'|'i'|'he'|'she'
      :verb      =~ 1.of('run','walk','blah')
      :adverb    =~ 'quickly'|'slowly'|['without', 'hesitation']
      :predicate =~ (0..1).of(:adverb, :verb, :object[/^.*$/])
      :sentence  =~ [:subject,:predicate]
    }
    g[:subject   ].inspect.should == %{(1..1):["you", "i", "he", "she"]}
    g[:verb      ].inspect.should == %{(1..1):["run", "walk", "blah"]}
    g[:adverb    ].inspect.should == %{(1..1):["quickly", "slowly", sequence:["without", "hesitation"]]}
    g[:predicate ].inspect.should ==%{(0..1):[::adverb, ::verb, /^.*$/]}
    g[:sentence  ].inspect.should ==%{sequence:[::subject, ::predicate]}
  end
  
  it "should work with symbol references" do
    g = Hipe.GorillaGrammar(:name=>:grammar2) {
      :alpha  =~ 'a'
      :beta   =~ 'b'
      :gamma  =~ 'c'
      :sentence  =~ [:alpha,:beta,:gamma]
    }
    g = Runtime.get_grammar :grammar2
    result = g.parse ['a','b','c']
    result.is_error?.should == false
  end
  
  def go str
    $g.parz str
  end
    
  it "should report expecting right at the start of a branch" do
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
  
  it "parse sequence 1 branch 2 x 2 x 1" do
    g = Hipe.GorillaGrammar {
      :sentence =~ [:manufacturer[ one_of %w(jimmy dean), %w(hickory farms) ] ]
    }
    thing = g.parse []
    thing.is_error?.should == true
    thing.should be_kind_of UnexpectedEndOfInput
    thing.tree.expecting.should == %w("jimmy" "hickory") 
  end  
  
  it "parse sequence 2 branch 2 x 2 x 1" do                                              
    g = Hipe.GorillaGrammar {                                                            
      :sentence =~ ['want','jimmy']  
    }                                                                                                                                                 
    thing = g.parse ['want']                                                     
    thing.is_error?.should == true                                                       
    thing.should be_kind_of UnexpectedEndOfInput                                         
    thing.tree.expecting.should == %w("jimmy")
  end                                     
  
  it "parse sequence 2 branch 2 x 2 x 1" do
    g = Hipe.GorillaGrammar {
      :sentence =~ ['want', :manufacturer[ one_of %w(jimmy dean), %w(hickory farms) ] ]
    }
    $stop =1 
    thing = g.parse ['want','jimmy']
    thing.is_error?.should == true
    thing.should be_kind_of UnexpectedEndOfInput
    thing.tree.expecting.should == %w("dean") 
  end  

end
