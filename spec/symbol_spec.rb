#rake spec SPEC=spec/symbol_spec.rb
require 'hipe-gorillagrammar'
include Hipe::GorillaGrammar

describe NonTerminalSymbol, "with respect to reflection" do
  before :each do 
    @g = Hipe.GorillaGrammar{ 
      :a_string                =~ "a string"
      :a_regexp                =~ /^[abc]+$/
      :a_sequence              =~ [:a_string, :a_regexp]  
      :a_range                 =~ (1..more).of(:a_string, :a_regexp)
      :a_range2                =~ (1..2).of(:a_string, :a_regexp)      
    }
  end
    
  it "should allow adequate basic reflection" do
    g = @g
    g.size.should == 5
    g[:a_string].should be_kind_of StringTerminal
    g[:a_regexp].should be_kind_of RegexpTerminal
    g[:a_sequence].should be_kind_of Sequence
    g[:a_range].should be_kind_of RangeOf
  end
  
  it "should allow reflection and retrieval" do
    g = @g
    g[:a_sequence].should be_kind_of Sequence
    g[:a_sequence].size.should == 2
    g[:a_sequence][0].should be_kind_of SymbolReference
    g[:a_sequence][1].should be_kind_of SymbolReference
    g[:a_range].size.should == 2
    g[:a_range][0].should be_kind_of SymbolReference
    g[:a_range][1].should be_kind_of SymbolReference    
    g[:a_range].range.should == (1..Infinity)
  end

  it "should allow useful inspect() calls" do
    g = @g
    g[:a_string].inspect.should == %{:a_string"a string"(_)}
    g[:a_regexp].inspect.should == %{:a_regexp/^[abc]+$/(_)}
    g[:a_sequence].inspect.should == %{:a_sequence[::a_string, ::a_regexp]}
    g[:a_range].inspect.should  == %<:a_range(1 or more):(::a_string, ::a_regexp)>
    g[:a_range2].inspect.should  == %<:a_range2(1..2):(::a_string, ::a_regexp)>    
  end
end