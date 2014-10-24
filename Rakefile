require 'bundler/setup'
require 'rake/testtask'
require 'bump/tasks'
require 'wwtd/tasks'

Rake::TestTask.new do |test|
  test.libs << 'lib'
  test.pattern = 'test/test_arhp.rb'
  test.verbose = true
end

task :default => 'wwtd:local'
