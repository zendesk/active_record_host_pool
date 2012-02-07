require 'rubygems'
require 'bundler/setup'

require 'appraisal'
require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/test_arhp.rb'
  test.verbose = true
end

task :default => :test
