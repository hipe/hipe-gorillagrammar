#rake spec SPEC=spec/runtime_spec.rb 
require 'hipe-gorillagrammar'
include Hipe::GorillaGrammar

describe Runtime do
  
  it "shortcuts should fail" do
    lambda {
      Runtime.not_there
    }.should raise_error(NoMethodError)
  end
  
  it "should return nil" do
    Runtime.current_grammar.should == nil    
  end
  
  it "should return nil again" do
    Runtime.current_grammar.should == nil    
  end

  it "should throw when there's no current grammar" do
    lambda{
      Runtime.current_grammar!
    }.should raise_error(UsageFailure)
  end
  
  it "should work violently" do
    g = nil     
    Hipe::GorillaGrammar.define {
      g = Runtime.current_grammar!
      ['']
    }
    g.should be_an_instance_of Grammar
  end
  
  it "should work calmly" do
    g = nil
    Hipe::GorillaGrammar.define {
      g = Runtime.current_grammar
      ['']      
    }
    g.should be_an_instance_of Grammar     
  end
  
  it "should not allow doubles" do
    lambda{
      Hipe::GorillaGrammar.define {
        Hipe::GorillaGrammar.define {}
        ['']        
      }
    }.should raise_error(UsageFailure)
  end  
  
  it "should work after" do
    Hipe::GorillaGrammar.define {['']}
    Runtime.current_grammar.should == nil
  end  

  it "grammar can only take symbols" do
    g = Hipe::GorillaGrammar.define {['']}
    lambda{ g[:a_symbol] = :not_a_symbol }.should raise_error(
      GorillaException, %{Expecting GorillaSymbol had :not_a_symbol}
    )
  end

end