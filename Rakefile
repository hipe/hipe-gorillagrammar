
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

RCov::VerifyTask.new(:rcovv => 'rcov') do |t|
  t.threshold = 95.0
  t.index_html = 'coverage/index.html'
end

desc 'Removes trailing whitespace'
task :whitespace do
  sh %{find . -name '*.rb' -exec sed -i '' 's/ *$//g' {} \\;}
end


