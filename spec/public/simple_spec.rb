# require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
require 'hipe-gorillagrammar'



describe "simple grammar" do

  it "should parse a simple sequence" do
    
    grammar = Hipe.GorillaGrammar do 
      one_or_more_of 'a','b','c'
    end
    
    debugger
    pp grammar
    exit
    
  #   result = grammar.parse 'a','b','c'
  end
end
