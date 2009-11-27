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

describe 'Regexp' do
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

describe 'And List Grammar' do
  before(:all){ @g = Hipe.GorillaGrammar{ :items  =~ [:item[/^.+$/], zero_or_more_of(['and', :item])]} }
  it("uno")   { @g.parse(['abc']).is_error?.should == false                        }
  it("uno.5") { @g.parse(['abc','and']).is_error?.should == true                   }
  it("dos")   { @g.parse(['abc','and','def']).is_error?.should == false            }
  it("tres")  { @g.parse(['abc','and','def','and','hij']).is_error?.should ==false }
end






