
# require 'spec'
require 'spec/rake/spectask'
require 'spec/rake/verify_rcov'

desc "Run API and Core specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_opts = ['--options', "\"#{File.dirname(__FILE__)}/spec/spec.opts\""]
  #t.spec_files = FileList['spec/public/**/*_spec.rb'] + FileList['spec/private/**/*_spec.rb']
  t.spec_files = FileList['spec/**/*_spec.rb'] + FileList['spec/private/**/*_spec.rb']  
end

desc "Run all examples with RCov"
Spec::Rake::SpecTask.new('rcov') do |t|
  t.spec_files = FileList['spec/**/*_spec.rb']
  t.rcov = true
  t.rcov_opts = ['--exclude', 'spec,/Library/Ruby/Gems/1.8/gems']
end

