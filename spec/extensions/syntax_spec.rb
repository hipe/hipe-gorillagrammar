#rake spec SPEC=spec/extensions/syntax_spec.rb
require 'hipe-gorillagrammar'
include Hipe::GorillaGrammar
require 'hipe-gorillagrammar/extensions/syntax'

describe ParseTree, 'in the context of Parsing' do

  before :all do
    @g = Hipe.GorillaGrammar {
      :dry             =~ zero_or_one([zero_or_one('as'),'dry',zero_or_one('run')])
      :delete_command  =~ ['delete',zero_or_one('deleted')]
      :add_command     =~ ['add',one('untracked','modified','both')]
      :help_command    =~ 'help'; :version_command =~ 'version'; :info_command =~ 'info'
      :command         =~ :add_command | :delete_command | :help_command | 
                          :version_command | :info_command
      :add_file        =~ ['add',one_or_more(:file)]
      :never_using_this =~ [(1..3).of(:blah)]
      :commands        =~ [:command,zero_or_more(['and',:command])]
    }
  end
 
  it "should put square brackets around zero or one (sx1)"  do
    @g[:delete_command].syntax.should == 'delete [deleted]'
  end
  
  it "should do a parenthesis and pipe thing for inline one (sx2)" do
    @g[:add_command].syntax.should == 'add (untracked|modified|both)'
  end
  
  it "should capitalize symbol references and put square brackets with ellipses around zero or more (sx3)" do
    @g[:commands].syntax.should == 'COMMAND [and COMMAND [...]]'
  end
  
  it "it should do the one or more thing (sx4)" do
    @g[:add_file].syntax.should == 'add FILE [FILE [...]]'
  end
  
  it "whatever ridiculous" do
    @g[:never_using_this].syntax.should == '(1..3) of (BLAH)'    
  end
end
