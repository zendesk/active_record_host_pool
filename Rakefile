require "bundler/setup"
require "rake/testtask"
require "rubocop/rake_task"
require "standard/rake"

Rake::TestTask.new do |test|
  test.pattern = "test/test_*.rb"
  test.verbose = true
  test.warning = true
end

task default: ["test", "standard:fix"]
