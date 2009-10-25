# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{curbit}
  s.version = "0.1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 1.2") if s.respond_to? :required_rubygems_version=
  s.authors = ["Scott Sayles"]
  s.date = %q{2009-10-25}
  s.description = %q{Application level rate limiting for Rails}
  s.email = %q{ssayles@users.sourceforge.net}
  s.extra_rdoc_files = ["LICENSE", "README.rdoc", "lib/curbit.rb"]
  s.files = ["LICENSE", "README.rdoc", "Rakefile", "init.rb", "lib/curbit.rb", "test/custom_key_controller_test.rb", "test/custom_message_format_controller.rb", "test/standard_controller_test.rb", "test/test_helper.rb", "test/test_rails_helper.rb", "Manifest", "curbit.gemspec"]
  s.homepage = %q{http://github.com/ssayles/curbit}
  s.rdoc_options = ["--line-numbers", "--inline-source", "--title", "Curbit", "--main", "README.rdoc"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{curbit}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Application level rate limiting for Rails}
  s.test_files = ["test/custom_key_controller_test.rb", "test/standard_controller_test.rb", "test/test_helper.rb", "test/test_rails_helper.rb"]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
