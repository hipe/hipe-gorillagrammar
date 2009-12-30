# rake spec SPEC=spec/range_spec.rb
require 'hipe-gorillagrammar'

module Hipe

  describe GorillaGrammar::RangeOf  do

    it "should not allow an empty grammar" do
      lambda {
        Hipe.GorillaGrammar { zero_or_more() }
      }.should raise_error(GorillaGrammar::GrammarGrammarException, 'Arguments must be non-zero length')
    end

    it "should pass if the grammar allows it" do
      grammar = Hipe.GorillaGrammar do
        zero_or_more 'a','b','c'
      end
      result = grammar.parse []
      result.should be_a_kind_of GorillaGrammar::ParseTree
    end

    it "should fail unless the grammar allows it" do
      grammar = Hipe.GorillaGrammar do
        one_or_more 'a','b','c'
      end
      result = grammar.parse []
      result.should be_a_kind_of GorillaGrammar::ParseFailure
    end

    it "should parse several tokens" do
      grammar = Hipe.GorillaGrammar do
        one_or_more 'a','b','c'
      end
      result = grammar.parse ['a','b','b','a']
    end

    it "should inspect as a grammar" do
      g = Hipe.GorillaGrammar { :sammy =~ (1..more).of('a','b','c') }
      s = g.inspect
      s.should match %r|sammy.*1.*"a".*"b".*"c"|m
    end

    it "is unlikely to have a minimum of two or more" do
      Hipe.GorillaGrammar{(2..more).of('jon','ringo','george','paul')}.parse(['jon','ringo']).is_error?.should == false
    end
  end  # when given non-zero
end
