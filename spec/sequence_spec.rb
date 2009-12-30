#rake spec SPEC=spec/sequence_spec.rb
require 'hipe-gorillagrammar'

module Hipe

  describe GorillaGrammar::Sequence do

    before(:each) do
      @abc = Hipe.GorillaGrammar do
        sequence 'a','b','c'
      end
    end

    it "should fail on empty sequence (s1)" do
      lambda {
        Hipe.GorillaGrammar { sequence() }
      }.should raise_error(GorillaGrammar::GrammarGrammarException, 'Arguments must be non-zero length')
    end

    it "should fail on empty input (s2)" do
      result = @abc.parse []
      result.should be_a_kind_of GorillaGrammar::ParseFailure
    end

    class MockyOneOff; # we couldn't use rspec for this because of marshaling
      include GorillaGrammar::GorillaSymbol
      def match(a); :/ ; end
      def status; :/ end
    end

    it "should compalin when symbol returns bad status (s3)" do
      mok = MockyOneOff.new
      g = Hipe.GorillaGrammar do
       :a =~ mok
       :sentence =~ [:a]
     end
     lambda{g.parse ['a','b'] }.should raise_error(GorillaGrammar::GorillaException, /bad status/)
    end

    it "should parse a simple one (s4)" do
      result = @abc.parse ['a','b','c']
      result.should be_a_kind_of GorillaGrammar::ParseTree
      result.should == ['a','b','c']
    end

    # s5 moved to parsing spec

    it "should work for simple compound (s6)" do
      grammar = Hipe.GorillaGrammar do
        sequence one_or_more('b','e'),'c'
      end
      result = grammar.parse ['b','c']
      result.is_error?.should == false
      result.to_a.should == [['b'],'c']
    end

     it "should parse a little more complex (s7)" do
       grammar = Hipe.GorillaGrammar do
         sequence 'a',one_or_more('b','e'),'c'
       end
       result = grammar.parse(['a','b','e','b','c'])
       result.is_error?.should == false
       result.to_a.should == ['a',['b','e','b'],'c']
     end

     it "should render expecting message jumping btwn two frames (s8)" do
       grammar = Hipe.GorillaGrammar do
         sequence zero_or_more('b','e'),'c'
       end
       result = grammar.parse(['d'])
       result.is_error?.should == true
       result.message.should match(/expecting(:? you to say)? "b", "e" or "c"/)
     end

     it "should handle zero or more at begin(s9)" do
       grammar = Hipe.GorillaGrammar do
         sequence zero_or_more('b','e'),'c'
       end
       result = grammar.parse(['b','e','c'])
       result.is_error?.should == false
       result.to_a.should == [['b','e'],'c']

     end
  end
end
