#rake spec SPEC=spec/grammar_spec.rb
require 'hipe-gorillagrammar'
include Hipe::GorillaGrammar

describe Grammar,'in general' do
  it "should allow basic reflection" do
    g = Hipe.GorillaGrammar{ :items =~ [:item[//]] }
    g.should be_a_kind_of Grammar
    g.size.should == 2
    (g.names - [:item,:items]).should == []
  end
end

describe Grammar,'in general' do
  it "should have entries in the symbol table for all its children" do
    g = Hipe.GorillaGrammar{ :items =~ [:item[//]] }
    g[:items].should_not == nil
    g[:item].should_not == nil  
  end
end

describe Grammar,'with respect to naming' do
  it "should get anonymous sequential names" do
    Runtime.instance.instance_variable_set '@grammars', {} 
    g1 = Hipe.GorillaGrammar{ :items =~ [:item[//]] }
    g2 = Hipe.GorillaGrammar{ :items =~ [:item[//]] }
    g3 = Hipe.GorillaGrammar{ :items =~ [:item[//]] }
    g4 = Hipe.GorillaGrammar(:name=>'yo, g'){ :items =~ [:item[//]] }
    g1.name.should == 'grammar1'
    g2.name.should == 'grammar2'    
    g3.name.should == 'grammar3'
    g4.name.should == 'yo, g'
  end
end

describe "In grammars, the bracket operator" do
  it "when there is only one native element in it which represents a terminal symbol, it should add such a symbol to the table" do
    g = Hipe.GorillaGrammar{ :items =~ [:item[//]] }
    g[:items].should be_kind_of Sequence
    g[:item].should be_kind_of RegexpTerminal    
  end  
end

describe Grammar do
  it "should not allow redefinitions of symbols" do
    lambda {
      Hipe.GorillaGrammar {
        :once =~ /espresso/
        :twice =~ ['i','love',:once[/coffee/]]
      }
    }.should raise_error GrammarGrammarException, /multiple definitions for :once/i
  end
end

describe Grammar, 'with respect to anonymous symbols' do
  it("still get entries in the symbol table if they're the last one") {
    g = Hipe.GorillaGrammar{[:item[//]]}
    g.size.should == 2
    g['__main__'].should be_kind_of Sequence    
  }
end

describe Grammar," with respect to brackets and symbol tables" do
  before :each do 
    @g1 = Hipe.GorillaGrammar {
      :thing       =~ "beans"
      :color       =~ /^(red|green)$/
      :noun_phrase =~ [:color, :thing]
    }
    @g2 = Hipe.GorillaGrammar {
      :noun_phrase =~ [:color[/^(red|green)$/], :thing["beans"]]
    }
    @g3 = Hipe.GorillaGrammar {
      :noun_phrase =~ [:color[/^(red|green)$/], :thing["beans"]]
      :billy =~ 'bob thornton'
    }
  end
 
  it "brackets should put entries in the symbol table and return symbol references" do
    g1,g2,g3 = @g1, @g2, @g3
    s1,s2    = '', ''
    PP.pp g1, s1
    PP.pp g2, s2
    s1.should == s2
    (g1==g2).should == true
    (g2==g1).should == true
    (g2==g3).should == false
  end
  
end

