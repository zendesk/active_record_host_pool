require "./lib/active_record_host_pool/version"

Gem::Specification.new do |s|
  s.name = "active_record_host_pool"
  s.version = ActiveRecordHostPool::VERSION
  s.authors = ["Benjamin Quorning", "Gabe Martin-Dempesy", "Pierre Schambacher", "Ben Osheroff"]
  s.email = ["bquorning@zendesk.com", "gabe@zendesk.com", "pschambacher@zendesk.com"]
  s.summary = "Allow ActiveRecord to share a connection to multiple databases on the same host"
  s.description = ""
  s.extra_rdoc_files = [
    "MIT-LICENSE",
    "Readme.md"
  ]
  s.files = Dir.glob("lib/**/*") + %w[Readme.md Changelog.md]
  s.homepage = "https://github.com/zendesk/active_record_host_pool"
  s.license = "MIT"

  s.required_ruby_version = ">= 3.1.0"

  s.add_runtime_dependency("activerecord", ">= 6.1.0")
end
