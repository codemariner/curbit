require 'rubygems'
require 'rake'
require 'echoe'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "curbit"
    gem.summary = %Q{Rails plugin for application level rate limiting}
    gem.description = %Q{TODO: longer description of your gem}
    gem.email = "ssayles@users.sourceforge.net"
    gem.homepage = "http://github.com/ssayles/curbit"
    gem.authors = ["Scott Sayles"]
    gem.add_development_dependency "thoughtbot-shoulda"
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

Echoe.new('curbit', '0.1.0') do |p|
  p.description = "Application level rate limiting for Rails"
  p.url = "http://github.com/ssayles/curbit"
  p.author = "Scott Sayles"
  p.email = "ssayles@users.sourceforge.net"
  p.ignore_pattern = ["tmp/*"]
  #p.develoment_dependencies = []
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/*_test.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION')
    version = File.read('VERSION')
  else
    version = ""
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "curbit #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
