Gem::Specification.new "active_record_host_pool", File.read(File.dirname(__FILE__) + "/VERSION") do |s|
  s.authors = ["Ben Osheroff"]
  s.date = "2012-06-11"
  s.summary = "Allow ActiveRecord to share a connection to multiple databases on the same host"
  s.description = ""
  s.email = ["ben@gimbo.net"]
  s.extra_rdoc_files = [
    "MIT-LICENSE",
    "Readme.md"
  ]
  s.files = [
    "Readme.md",
    "lib/active_record_host_pool.rb",
    "lib/active_record_host_pool/connection_adapter_mixin.rb",
    "lib/active_record_host_pool/connection_proxy.rb",
    "lib/active_record_host_pool/pool_proxy.rb"
  ]
  s.homepage = "https://github.com/zendesk/active_record_host_pool"
  s.test_files = ["test/database.yml", "test/helper.rb", "test/schema.rb", "test/test_arhp.rb"]
  s.license = "MIT"

  s.add_runtime_dependency("activerecord")

  s.add_development_dependency("wwtd")
end
