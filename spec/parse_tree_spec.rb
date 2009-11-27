#rake spec SPEC=spec/parse_tree_spec.rb
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


describe 'ParseTree' do
  before :all do
    @g = Hipe.GorillaGrammar {                                                            
      :sentence[:color[/^(red|green)$/], 'beans', 'and', :food[/^salad|rice$/]]
    }
  end
  it "should succeed with simple regexp" do                                              
    tree = @g.parse(['red','beans','and','rice'])
    tree.is_error?.should == false
  end
  it "should fail with simple regexp" do                                              
    tree = @g.parse(['blue','beans','and','rice'])
    tree.is_error?.should == true
  end

end
