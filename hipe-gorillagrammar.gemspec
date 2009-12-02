# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{hipe-gorillagrammar}
  s.version = "0.0.1beta"

  s.required_rubygems_version = Gem::Requirement.new("> 1.3.1") if s.respond_to? :required_rubygems_version=
  s.authors = ["Mark Meves"]
  s.date = %q{2009-11-23}
  s.description = %q{LR Parser Generator (?) under 500 LOC with 100*% C1 test coverage.  No useful AST yet.  No useful docs yet.}
  s.email = %q{mark.meves@gmail.com}
  s.files = [
    ".gitignore",
    "History.txt",
    "LICENSE.txt",
    "README.txt",
    "Rakefile",
    "Thorfile",
    "lib/hipe-gorillagrammar.rb",
    "spec/argv.rb",
    "spec/grammar_spec.rb",
    "spec/helpers.rb",
    "spec/parse_tree_spec.rb",
    "spec/parsing_spec.rb",
    "spec/range_spec.rb",
    "spec/regexp_spec.rb",
    "spec/runtime_spec.rb",
    "spec/sequence_spec.rb",
    "spec/shorthand_spec.rb",
    "spec/spec.opts",
    "spec/symbol_reference_spec.rb",
    "spec/symbol_spec.rb"
  ]
  s.has_rdoc = %q{yard}
  s.homepage = %q{http://github.com/hipe/hipe-gorillagrammar}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{'beta attempt at a simple LR parser generator driven by DSL under 500LOC 100% C1 test coverage'}
  s.test_files = [
    "spec/argv.rb",
    "spec/grammar_spec.rb",
    "spec/helpers.rb",
    "spec/parse_tree_spec.rb",
    "spec/parsing_spec.rb",
    "spec/range_spec.rb",
    "spec/regexp_spec.rb",
    "spec/runtime_spec.rb",
    "spec/sequence_spec.rb",
    "spec/shorthand_spec.rb",
    "spec/symbol_reference_spec.rb",
    "spec/symbol_spec.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
