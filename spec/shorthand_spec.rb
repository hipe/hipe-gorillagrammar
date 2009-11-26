# rake spec SPEC=spec/shorthand_spec.rb 
require 'hipe-gorillagrammar'

include Hipe::GorillaGrammar

describe Runtime do
  
  it "should return nil" do
    Runtime.current_grammar.should == nil    
  end
  
  it "should return nil again" do
    Runtime.current_grammar.should == nil    
  end

  it "should throw when there's no current grammar" do
    lambda{
      Runtime.current_grammar!
    }.should raise_error(UsageFailure)
  end

   it "should work violently" do
     g = nil     
     Hipe::GorillaGrammar.define {
       g = Runtime.current_grammar!
     }
     g.should be_an_instance_of Grammar
   end
   
   it "should work calmly" do
     g = nil
     Hipe::GorillaGrammar.define {
       g = Runtime.current_grammar
     }
     g.should be_an_instance_of Grammar     
   end
   
   it "should not allow doubles" do
     lambda{
       Hipe::GorillaGrammar.define {
         Hipe::GorillaGrammar.define {}
       }
     }.should raise_error(UsageFailure)
   end  
   
   it "should work after" do
     Hipe::GorillaGrammar.define {
 
     }
     Runtime.current_grammar.should == nil
   end  
   
 end
 
 
 
# describe Hipe::GorillaGrammar, "with shorthands" do
#   it "should parse with stub functions" do
#     g = Hipe.GorillaGrammar {
#       :subject   =~ 'you' || 'i' || 'we'
#       :verb      =~ (1.of 'run','walk','blah')
#       :predicate =~ [(0..1).of :adverb, :verb, :object[/^.*$/]]
#       :sentence  =~ [:subject,:predicate]
#     }
#     
#     pending "this would be awesome"
#   end
   

 
