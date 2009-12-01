#rake spec SPEC=spec/parsing_spec.rb
require 'hipe-gorillagrammar'
include Hipe::GorillaGrammar


describe ParseTree, 'in the context of Parsing' do

  it("should parse with the empty grammar")   { 
    Hipe.GorillaGrammar{ (0..more).of('') }.parse([]).is_error?.should == false
  }

  it("should parse with the one token grammar") {
    g = Hipe.GorillaGrammar{[:item[//]]}
    tree = g.parse(['abc'])
    tree.is_error?.should == false
  }
  
end

describe "in the context of Parsing, a simple union grammar" do
  before :each do 
    @g_union = Hipe.GorillaGrammar { :base =~  'mac' | 'whopper' }
  end
  
  it "(u0) should allow two ways to define union -- pipe and named functions" do
    g1 = @g_union
    g2 = Hipe.GorillaGrammar{ :base =~  one('mac','whopper') }
    g3 = Hipe.GorillaGrammar{ :base =~  one('mac','whopper',['bk','broiler']) }    
    g1.should == g2
    g1.should_not == g3
  end
  
  it "(u1) should raise unexpected end when zero tokens" do 
    g = @g_union
    result = g.parse []
    result.is_error?.should == true
    result.should be_kind_of UnexpectedEndOfInput
    result.message.should be_kind_of String
  end
  
  it "(u2) should parse one correct token" do
    result = @g_union.parse ['mac']
    result.is_error?.should == false
    result.should be_kind_of(RangeOf)
    result.size.should == 1
    result[0].should == 'mac'
  end
  
  it "(u3) should raise unexpected with one incorrect token" do
    result = @g_union.parse ['falafel']
    result.is_error?.should == true
    result.should be_kind_of(UnexpectedInput)
    result.message.should be_kind_of(String)
  end
  
  it "(u4) should raise unexpected with extra token" do
    result = @g_union.parse ['mac','falafel']
    result.is_error?.should == true
    result.should be_kind_of(UnexpectedInput)
    result.message.should be_kind_of(String)
  end  
end
  
describe "in the context of Parsing, a simple concatenated grammar" do  
  
  before :each do 
    @g_concat = Hipe.GorillaGrammar { :base =~ [ 'big' , 'mac' ] }
  end  
  
  it "(c1) should raise unexpected end when it has zero tokens" do 
    g = @g_concat
    result = g.parse []
    result.is_error?.should == true
    result.should be_kind_of UnexpectedEndOfInput
    result.message.should be_kind_of String
  end
  
  it "(c2) should raise unexpected end when nonzero not enough tokens" do 
    g = @g_concat
    result = g.parse ['big']
    result.is_error?.should == true
    result.should be_kind_of UnexpectedEndOfInput
    result.message.should be_kind_of String
  end
  
  it "(c3) should raise unexpected with one bad token " do
    g = @g_concat
    result = g.parse ['falafel']
    result.is_error?.should == true
    result.should be_kind_of UnexpectedInput
    result.message.should be_kind_of String   
  end  
  
  it "(c4) should parse correctly " do
    g = @g_concat
    result = g.parse ['big','mac']
    result.is_error?.should == false
    result.should be_kind_of Sequence
    result.size.should == 2
  end
  
  it "(c5) with the second token being bad should raise unexpected" do 
    g = @g_concat
    result = g.parse ['big','falafel']
    result.is_error?.should == true
    result.should be_kind_of UnexpectedInput
    result.message.should be_kind_of String
  end
  
  it "(c6) with too many tokens should raise unexpected" do 
    g = @g_concat
    result = g.parse ['big','mac','attack']
    result.is_error?.should == true
    result.should be_kind_of UnexpectedInput
    result.message.should be_kind_of String
  end
  
end

describe "in the context of Parsing a simple sequence (same as concat)" do
  before(:each) do 
    @abc = Hipe.GorillaGrammar do
      sequence 'a','b','c'
    end
  end

  it "should fail with a message when expecting more (s5)" do
    result = @abc.parse(['a','b'])
    result.is_error?.should == true
    result.message.should match(/unexpected end of input/i)      
    result.message.should match(/expecting(?: you to say) "c"/i)
  end

end

  
describe "in the context of Parsing, an integrated union and concat with leading union" do
  before :each do
    @g1 = Hipe.GorillaGrammar do
      sequence zero_or_more('real','big'),'burger'
    end
  end
  
  it "(i1) should fail on zero" do
    r = @g1.parse []
    r.is_error?.should == true
    r.should be_kind_of(UnexpectedEndOfInput)
    r.message.should match(/expecting.*real.*big.*burger/i)
  end
  
  it "(i2) should fail on one bad token" do
    r = @g1.parse ['falafel']
    r.is_error?.should == true
    r.should be_kind_of(UnexpectedInput)
    r.message.should match(/expecting.*real.*big.*burger/i)
  end
  
  it "(i3) should fail on a second bad token" do
    r = @g1.parse ['real','falafel']
    r.is_error?.should == true
    r.should be_kind_of(UnexpectedInput)
    r.message.should match(/expecting.*real.*big.*burger/i)
  end
  
  it "(i4) should fail on a third bad token A" do
    r = @g1.parse ['real','big','falafel']
    r.is_error?.should == true
    r.should be_kind_of(UnexpectedInput)
    r.message.should match(/expecting.*real.*big.*burger/i)
  end

  it "(i5) should fail on a an extra token" do
    r = @g1.parse ['real','big','burger','falafel']
    r.is_error?.should == true
    r.should be_kind_of(UnexpectedInput)
    r.message.should match(/wasn't expecting/i)
  end

  it "(i6) should parse correctly A" do
    r = @g1.parse ['burger']
    r.is_error?.should == false
    r.size.should == 2
  end

  it "(i7) should parse correctly B" do
    r = @g1.parse ['real','burger']
    r.is_error?.should == false
    r.size.should == 2
  end

  it "(i8) should parse correctly C" do
    r = @g1.parse ['real','big','burger']
    r.is_error?.should == false
    r.size.should == 2
  end

  it "(i9) should parse correctly D" do
    r = @g1.parse ['real','big','real','burger']
    r.is_error?.should == false
    r.size.should == 2
  end

end  
  

describe "in the context of Parsing, an integrated union and concat with trailing union" do
  before :each do
    @g1 = Hipe.GorillaGrammar do
      sequence one('burger','goat'),zero_or_more(['with','fries'],['with','falafel'])
    end
  end

  it "(j1) should fail on zero" do
    r = @g1.parse []
    r.is_error?.should == true
    r.should be_kind_of(UnexpectedEndOfInput)
    r.message.should match(/expecting.*burger.*goat/i)
  end

  it "(j2) should fail on one bad token" do
    r = @g1.parse ['falafel']
    r.is_error?.should == true
    r.should be_kind_of(UnexpectedInput)
    r.message.should match(/expecting.*burger.*goat/i)
  end

  it "(j3) should fail on a second bad token (and do uniq on expecting tokens)" do
    r = @g1.parse ['burger','without']
    r.is_error?.should == true
    r.should be_kind_of(UnexpectedInput)
    r.message.should match(/expecting.*with/i)
  end

  it "(j4) should fail on a third bad token A" do
    r = @g1.parse ['burger','with','toast']
    r.is_error?.should == true
    r.should be_kind_of(UnexpectedInput)
    r.message.should match(/expecting.*fries.*falafel.*end/i)
  end

  it "(j5) should fail on two extra tokens" do
    r = @g1.parse ['burger','with','fries','to','go']
    r.is_error?.should == true
    r.should be_kind_of(UnexpectedInput)
    r.message.should match(/(?:wasn't expecting|don't know what you mean by).*to.*end/i)
  end

  it "(j6) should parse correctly A" do
    r = @g1.parse ['burger']
    r.is_error?.should == false
    r.size.should == 1
  end

  it "(j7) should parse correctly B" do
    r = @g1.parse ['burger','with','falafel']
    r.is_error?.should == false
    r.size.should == 2
  end

  it "(j8) should parse correctly C" do
    r = @g1.parse ['goat','with','fries']
    r.is_error?.should == false
    r.size.should == 2
  end

  # no j9.  there are only 3 permutations of correct productions

  
  it "parse sequence 2 branch 2 x 2 x 1 (h15)" do
    g = Hipe.GorillaGrammar {
      :sentence =~ ['want', :manufacturer[ one %w(jimmy dean), %w(hickory farms) ] ]
    }
    $stop =1 
    thing = g.parse ['want','jimmy']
    thing.is_error?.should == true
    thing.should be_kind_of UnexpectedEndOfInput
    thing.tree.expecting.should == %w("dean") 
  end

end
  
describe "test" do

  it "union of concat"
end    

describe 'in the context of Parsing, an "and-list" gramar' do
  before(:all){ 
    @g = Hipe.GorillaGrammar{ :items  =~ [:item[/^.+$/],(0..more).of(['and', :item])]} 
    @g = Hipe.GorillaGrammar{ [:item[/^.+$/]] }
  }
  it("uno")   { 
    @g.parse(['abc']).is_error?.should == false                        
  }
end


describe 'in the context of Parsing, an "and-list" gramar' do
  before(:all){ @g = Hipe.GorillaGrammar{ :items  =~ [:item[/^.+$/],(0..more).of(['and', :item])]} }
  it("uno")   { @g.parse(['abc']).is_error?.should == false                        }
  it("uno.5") { @g.parse(['abc','and']).is_error?.should == true                   }
  it("dos")   { @g.parse(['abc','and','def']).is_error?.should == false            }
  it("tres")  { @g.parse(['abc','and','def','and','hij']).is_error?.should ==false }
end
