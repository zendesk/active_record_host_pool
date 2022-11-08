require './lib/active_record_host_pool/version'

Gem::Specification.new do |s|
  s.name = "active_record_host_pool"
  s.version = ActiveRecordHostPool::VERSION
  s.authors = ["Benjamin Quorning", "Gabe Martin-Dempesy", "Pierre Schambacher", "Ben Osheroff"]
  s.email   = ["bquorning@zendesk.com", "gabe@zendesk.com", "pschambacher@zendesk.com"]
  s.summary = "Allow ActiveRecord to share a connection to multiple databases on the same host"
  s.description = ""
  s.extra_rdoc_files = [
    "MIT-LICENSE",
    "Readme.md"
  ]
  s.files = [
    "Readme.md",
    "lib/active_record_host_pool.rb",
    "lib/active_record_host_pool/clear_query_cache_patch.rb",
    "lib/active_record_host_pool/connection_adapter_mixin.rb",
    "lib/active_record_host_pool/connection_proxy.rb",
    "lib/active_record_host_pool/pool_proxy.rb",
    "lib/active_record_host_pool/pool_proxy_6_1.rb",
    "lib/active_record_host_pool/pool_proxy_legacy.rb",
    "lib/active_record_host_pool/version.rb"
  ]
  s.homepage = "https://github.com/zendesk/active_record_host_pool"
  s.test_files = ["test/database.yml", "test/helper.rb", "test/schema.rb", "test/test_arhp.rb"]
  s.license = "MIT"

  s.required_ruby_version = ">= 2.6.0"

  s.add_runtime_dependency("activerecord", ">= 5.1.0", "< 7.1")
  s.add_runtime_dependency("mysql2")

  s.add_development_dependency("bump")
  s.add_development_dependency("minitest", ">= 5.10.0")
  s.add_development_dependency("minitest-mock_expectations", "~> 1.1.3")
  s.add_development_dependency("phenix", ">= 1.0.1")
  s.add_development_dependency("rake", '>= 12.0.0')
  s.add_development_dependency('rubocop', '~> 0.80.0')
end
