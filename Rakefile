require "bundler/setup"
require "bundler/gem_tasks"
require "rake/testtask"
require "rubocop/rake_task"
require "standard/rake"

# Pushing to rubygems is handled by a github workflow
ENV["gem_push"] = "false"

Rake::TestTask.new do |test|
  test.pattern = "test/test_*.rb"
  test.verbose = true
  test.warning = true
end

task default: ["test", "standard:fix"]
