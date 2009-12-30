#rake spec SPEC=spec/symbol_reference_spec.rb
require 'hipe-gorillagrammar'
include Hipe::GorillaGrammar

describe SymbolReference do

#  it "parse sequence 2 branch 2 x 2 x 1 trailing union w/o symbol references (sr1)" do
#    g = Hipe.GorillaGrammar {
#      :sentence =~ ['want', one( %w(jimmy dean), %w(hickory farms) ) ]
#    }
#    thing = g.parse ['want','jimmy']
#    thing.is_error?.should == true
#    thing.should be_kind_of UnexpectedEndOfInput
#    thing.tree.expecting.should == %w("dean")
#  end
#
  it "parse sequence 2 branch 2 x 2 x 1 (h15)" do
    g = Hipe.GorillaGrammar {
      :sentence =~ ['want', :manufacturer[ one %w(jimmy dean), %w(hickory farms) ] ]
    }
#    debugger
    thing = g.parse ['want','jimmy']
    thing.is_error?.should == true
    thing.should be_kind_of UnexpectedEndOfInput
    thing.tree.expecting.should == %w("dean")
  end

end
