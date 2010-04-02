# require File.expand_path(File.dirname(__FILE__) + "/../spec_helper")
describe "simple grammar" do

  before(:all) do 
    
  end

  it "should parse simple simple stuff" do
    g = Hipe::GorillaGrammar.is do
      one_or_more_of ['a','b','c']
    end
    
    result = g.parse 'a','a','c'
    
    result = g.parse()
    
    
    
    
  end

end