# require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require 'hipe-gorillagrammar'

module Hipe

  describe GorillaGrammar, "when given a list of zero input" do
   
   it "should not allow an empty grammar" do
     lambda {
       Hipe.GorillaGrammar { zero_or_more_of() }
     }.should raise_error(GorillaGrammar::GrammarGrammarException, 'Arguments must be non-zero length')
   end
   
   it "should pass if the grammar allows it" do 
      grammar = Hipe.GorillaGrammar do
        zero_or_more_of 'a','b','c'
      end
      result = grammar.parse []
      result.should be_a_kind_of GorillaGrammar::ParseTree
    end
   
   it "should fail unless the grammar allows it" do
     grammar = Hipe.GorillaGrammar do 
       one_or_more_of 'a','b','c'
     end
     result = grammar.parse []
     result.should be_a_kind_of GorillaGrammar::ParseFailure
   end
  end
  

  describe GorillaGrammar, "when given a list of nonzero input" do
   
    it "should parse several tokens" do
      grammar = Hipe.GorillaGrammar do
        one_or_more_of 'a','b','c'
      end
      result = grammar.parse ['a','b','b','a']
    end
  end  # when given non-zero
end