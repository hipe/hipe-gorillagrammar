require 'hipe-gorillagrammar'

module Hipe::GorillaGrammar
  
  describe RangeOf,'when producing language' do
    it "should create or-lists correctly" do
      RangeOf.join(['a','b','c','d'],', ',' or '){|x| %{"#{x}"}}.should == 
        %{"a", "b", "c" or "d"}
      RangeOf.join(['a','b','c'],', ',' or '){|x| %{"#{x}"}}.should == 
        %{"a", "b" or "c"}
      RangeOf.join(['a','b'],', ',' or '){|x| %{"#{x}"}}.should == 
        %{"a" or "b"}
      RangeOf.join(['a'],', ',' or '){|x| %{"#{x}"}}.should == 
        %{"a"}
      RangeOf.join([],', ',' or '){|x| %{"#{x}"}}.should == 
        %{}
    end
  end
end