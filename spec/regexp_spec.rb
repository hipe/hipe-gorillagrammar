#rake spec SPEC=spec/regexp_spec.rb
require 'hipe-gorillagrammar'
include Hipe::GorillaGrammar


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
