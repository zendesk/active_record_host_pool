Gem::Specification.new do |s|
  s.name = %q{active_record_host_pool}
  s.version = "0.4.0"

  s.authors = ["Ben Osheroff"]
  s.date = %q{2011-10-28}
  s.description = %q{}
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
  s.homepage = %q{http://github.com/zendesk/active_record_host_pool}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.5.3}
  s.summary = %q{When connecting to databases on one host, use just one connection}
  s.test_files = ["test/database.yml", "test/helper.rb", "test/schema.rb", "test/test_arhp.rb"]

  s.add_runtime_dependency(%q<activerecord>, [">= 0"])
  s.add_development_dependency(%q<rake>, [">= 0"])
  s.add_development_dependency(%q<bundler>, [">= 0"])
  s.add_development_dependency(%q<shoulda>, [">= 0"])
  s.add_development_dependency(%q<mocha>, [">= 0"])
  s.add_development_dependency(%q<ruby-debug>, [">= 0"])
end

