#require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
#rake spec SPEC=spec/sequence_spec.rb 
require 'hipe-gorillagrammar'

module Hipe

  describe GorillaGrammar::Sequence do
   
    before(:each) do 
      @abc = Hipe.GorillaGrammar do
        sequence 'a','b','c'
      end
    end
   
    it "should fail on empty sequence" do
      lambda {
        Hipe.GorillaGrammar { sequence() }
      }.should raise_error(GorillaGrammar::GrammarGrammarException, 'Arguments must be non-zero length')
    end
   
    it "should fail on empty input" do 
      result = @abc.parse []
      result.should be_a_kind_of GorillaGrammar::ParseFailure
    end
   
    it "should parse a simple one" do
      result = @abc.parse ['a','b','c']
      result.should be_a_kind_of GorillaGrammar::ParseTree
      result.should == ['a','b','c']
    end
    
    it "should fail with a message when expecting more" do
      result = @abc.parse(['a','b'])
      result.is_error?.should == true
      result.message.should match(/unexpected end of input/i)      
      result.message.should match(/expecting(?: you to say) "c"/i)
    end

    it "should work for simple compound" do
      grammar = Hipe.GorillaGrammar do
        sequence one_or_more_of('b','e'),'c'
      end
      result = grammar.parse ['b','c']
      result.is_error?.should == false
      result.to_a.should == [['b'],'c']
    end
    
     it "should parse a little more complex" do
       grammar = Hipe.GorillaGrammar do
         sequence 'a',one_or_more_of('b','e'),'c'
       end
       result = grammar.parse(['a','b','e','b','c'])
       result.is_error?.should == false
       result.to_a.should == ['a',['b','e','b'],'c']
     end    
     
     it "should render expecting message jumping btwn two frames" do
       grammar = Hipe.GorillaGrammar do
         sequence zero_or_more_of('b','e'),'c'
       end      
       result = grammar.parse(['d'])
       result.is_error?.should == true
       result.message.should match(/expecting(:? you to say)? "b", "e" or "c"/)
     end
     
     it "should handle zero or more at begin" do
       grammar = Hipe.GorillaGrammar do
         sequence zero_or_more_of('b','e'),'c'
       end
       result = grammar.parse(['b','e','c'])
       result.is_error?.should == false
       result.to_a.should == [['b','e'],'c']
       
     end    
  end

end 