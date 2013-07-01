require 'bundler/setup'
require 'appraisal'
require 'rake/testtask'
require 'bump/tasks'

Rake::TestTask.new do |test|
  test.libs << 'lib'
  test.pattern = 'test/test_arhp.rb'
  test.verbose = true
end

task :default => :test
