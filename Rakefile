require 'rubygems'
require 'rake'
require 'spec/rake/spectask'
require 'spec/rake/verify_rcov'

desc "Run API and Core specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_opts = ['--options', "\"#{File.dirname(__FILE__)}/spec/spec.opts\""]
  t.spec_files = FileList['spec/public/**/*_spec.rb'] + FileList['spec/private/**/*_spec.rb']
end

begin
  gem 'jeweler', '~> 1.4'
  require 'jeweler'

  Jeweler::Tasks.new do |gem|
    gem.name        = 'hipe-gorillagrammar'
    gem.summary     = 'how i serialize the non-linear'
    gem.summary   = %q{'beta attempt at a simple LR parser generator driven by DSL under 500LOC 100% C1 test coverage'}
    gem.description  = <<-EOS.strip
    Failed early attempt at LR Parser Generator (?)
    in under 500 LOC with 100*% C1 test coverage.  No useful AST yet.  No useful docs yet.
    cool looking DSL though that looks a bit like BNF
    EOS
    gem.email       = 'chip.malice@gmail.com'
    gem.homepage    = 'http://github.com/hipe/hipe-gorillagrammar'
    gem.authors     = [ 'Chip Malice' ]
    gem.bindir      = 'bin'
    # gem.rubyforge_project = 'none'

    gem.add_dependency 'hipe-cli',    '~> 0.0.0'
  end

  Jeweler::GemcutterTasks.new

  # FileList['tasks/**/*.rake'].each { |task| import task }
rescue LoadError
  puts 'Jeweler (or a dependency) not available. Install it with: gem install jeweler'
end

desc "hack turns the installed gem into a symlink to this directory"

task :hack do
  kill_path = %x{gem which hipe-gorillagrammar}
  kill_path = File.dirname(File.dirname(kill_path))
  new_name  = File.dirname(kill_path)+'/ok-to-erase-'+File.basename(kill_path)
  FileUtils.mv(kill_path, new_name, :verbose => 1)
  this_path = File.dirname(__FILE__)
  FileUtils.ln_s(this_path, kill_path, :verbose => 1)
end
