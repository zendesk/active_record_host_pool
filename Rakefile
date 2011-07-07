require 'bundler'
Bundler::GemHelper.install_tasks :name => 'active_record_host_pool'


require 'jeweler'
Jeweler::Tasks.new do |s|
  s.name        = "active_record_host_pool"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ben Osheroff"]
  s.email       = ["ben@gimbo.net"]
  s.homepage    = "http://github.com/zendesk/active_record_host_pool"
  s.summary     = "When connecting to databases on one host, use just one connection"
  s.description = ""

  s.add_runtime_dependency("activerecord", "~> 2.3.5")

  s.add_development_dependency("rake")
  s.add_development_dependency("bundler")
  s.add_development_dependency("shoulda")
  s.add_development_dependency("mocha")

  if RUBY_VERSION < "1.9"
    s.add_development_dependency("ruby-debug")
  else
    s.add_development_dependency("ruby-debug19")
  end

  s.files        = Dir.glob("lib/**/*") + %w(README.md)
  s.test_files   = Dir.glob("test/**/*")
  s.require_path = 'lib'
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/*_test.rb'
  test.verbose = true
end
