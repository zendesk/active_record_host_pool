Gem::Specification.new do |s|
  s.name = "active_record_host_pool"
  s.version = "0.6.1"

  s.authors = ["Ben Osheroff"]
  s.date = %q{2011-10-28}
  s.summary = "Allow ActiveRecord to share a connection to multiple databases on the same host"
  s.description = ""
  s.email = ["ben@gimbo.net"]
  s.extra_rdoc_files = [
    "LICENSE",
    "README.md"
  ]
  s.files = [
    "README.md",
    "lib/active_record_host_pool.rb",
    "lib/active_record_host_pool/connection_adapter_mixin.rb",
    "lib/active_record_host_pool/connection_proxy.rb",
    "lib/active_record_host_pool/pool_proxy.rb"
  ]
  s.homepage = "http://github.com/zendesk/active_record_host_pool"
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.5.3}
  s.test_files = ["test/database.yml", "test/helper.rb", "test/schema.rb", "test/test_arhp.rb"]

  s.add_runtime_dependency("activerecord")
  s.add_development_dependency("rake")
  s.add_development_dependency("shoulda")
  s.add_development_dependency("mysql")
  s.add_development_dependency("mysql2")
  s.add_development_dependency("mocha")
  if RUBY_VERSION < "1.9.0"
    s.add_development_dependency("ruby-debug") 
  else
    s.add_development_dependency("debugger")
  end
end

