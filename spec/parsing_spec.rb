#rake spec SPEC=spec/parsing_spec.rb
require 'hipe-gorillagrammar'
include Hipe::GorillaGrammar

describe ParseTree, 'in the context of parsing' do

  it("should parse with the empty grammar")   { 
    Hipe.GorillaGrammar{ (0..more).of('') }.parse([]).is_error?.should == false
  }

  it("should parse with the one token grammar") {
    g = Hipe.GorillaGrammar{[:item[//]]}
    tree = g.parse(['abc'])
    tree.is_error?.should == false
  }
  
end

describe "Parsing logic" do
  it "should complain on unexpected tokens" do
    g2 = Hipe.GorillaGrammar{
      :base =~  one(['mac'],['whopper'])  
    }
    result = g2.parse(['mac','faq'])
    result.is_error?.should == true
    result.should be_kind_of UnexpectedInput
  end
end


describe 'with respect to parse trees, an "and-list" gramar' do
  before(:all){ 
    @g = Hipe.GorillaGrammar{ :items  =~ [:item[/^.+$/],(0..more).of(['and', :item])]} 
    @g = Hipe.GorillaGrammar{ [:item[/^.+$/]] }
  }
  it("uno")   { 
    @g.parse(['abc']).is_error?.should == false                        
  }
end


describe RegexpTerminal, 'in the context of parsing' do
  before :all do
    @g = Hipe.GorillaGrammar {                                                            
      :sentence =~ [:color[/^(red|green)$/], 'beans', 'and', :food[/^salad|rice$/]]
    }
  end
  
  it "cannot parse on its own" do
    g = Hipe.GorillaGrammar{ :item =~ //   }
    lambda{ t = g.parse ['alpha'] }.should raise_error NoMethodError, /undefined method `parse'/ 
  end

  it "should fail with simple regexp" do
    g = @g                                         
    tree = @g.parse(['blue','beans','and','rice'])
    tree.is_error?.should == true
  end

end


describe 'with respect to parse trees, an "and-list" gramar' do
  before(:all){ @g = Hipe.GorillaGrammar{ :items  =~ [:item[/^.+$/],(0..more).of(['and', :item])]} }
  it("uno")   { @g.parse(['abc']).is_error?.should == false                        }
  it("uno.5") { @g.parse(['abc','and']).is_error?.should == true                   }
  it("dos")   { @g.parse(['abc','and','def']).is_error?.should == false            }
  it("tres")  { @g.parse(['abc','and','def','and','hij']).is_error?.should ==false }
end
