#rake spec SPEC=spec/bug_spec.rb
require 'hipe-gorillagrammar'
include Hipe::GorillaGrammar


describe "bug" do

  before :each do
    @g1 = Hipe.GorillaGrammar {
      :whitespace =~ ['ws',zero_or_one('fix')]
      :other =~ ['other']
      :command =~ :whitespace | :other
    }
  end

  it "should parse trailing (b1)" do 
    g = @g1
    res = g.parse %w(ws fix)
    res.is_error?.should == false
    res.size.should == 1
  end
  
  it "should parse no trailing (b2)" do 
    g = @g1
    res = g.parse %w(ws)
    res.is_error?.should == false
    res.size.should == 1
  end
  
end
