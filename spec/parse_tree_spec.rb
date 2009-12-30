#rake spec SPEC=spec/parse_tree_spec.rb
require 'hipe-gorillagrammar'
include Hipe::GorillaGrammar


describe "ParseTree with fun grammar" do

  before :each do
    @g1 = Hipe.GorillaGrammar {
      :mode      =~    one(['bike'],['walk'],['take','the','train'])
      :person    =~    /\A.*\Z/
      :modes     =~    [:mode, zero_or_more(['and', :mode])]
      :sentence  =~    [:person, 'will', :modes, 'home']
    }
  end

  it "should parse this fun grammar (pt1)" do
    g = @g1
    res = g.parse %w(mark will take the train home)
    res.is_error?.should == false
    res.size.should == 4

    res = g.parse %w(fecetious will swim)
    res.is_error?.should == true
    res.tree.expecting.should == %w("bike" "walk" "take")

    res = g.parse(%w(yoko will bike and walk and take the train home))
    res.is_error?.should == false
  end

  it "should pp this fun grammar (pt2)" do
    res = @g1.parse(%w(yoko will bike and walk and take the train home))
    num_of_things_deleted = res.recurse{ |x| x.prune! }
    num_of_things_deleted.should be > 30
    num_of_things_deleted.should be < 80   # was 59 at one point.  whatever
    # puts %{number of things deleted: #{num_of_things_deleted}}
    PP.pp(res,s = '')
    s.should be_kind_of String
    s.length.should be_close(650, 350)
  end

  it "should unparse (pt3)" do
    # this is such a small example but i can't explain how awesome it is.
    res = @g1.parse(%w(yoko will bike and walk and take the train home))
    tokens = res.recurse{|x| x.tokens}
    tokens.should == %w(yoko will bike and walk and take the train home)
  end

end

describe RangeOf,' in the context of ParseTrees' do
  it "should create or-lists correctly (ptro1)" do
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
