require 'rubygems'
require 'appraisal'
require 'bundler/setup'

require 'rake/testtask'
Rake::TestTask.new do |test|
  test.libs << 'lib'
  test.pattern = 'test/test_arhp.rb'
  test.verbose = true
end

task :default do
  sh "bundle exec rake appraisal:install && bundle exec rake appraisal test"
end
