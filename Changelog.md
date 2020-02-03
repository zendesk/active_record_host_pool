### Unreleased

### 0.13.0

Add support for Rails 5.2.3. See more details in the PR description: (https://github.com/zendesk/active_record_host_pool/pull/48)

Stop testing with EOL Ruby 2.3 (https://github.com/zendesk/active_record_host_pool/pull/49)

### 0.12.0

Ruby/Rails updates: (https://github.com/zendesk/active_record_host_pool/pull/40)
 - Drops compatibility with Rails 3.2 (and lower) and Rails 5.0.x.
 - Stops testing with Ruby 2.2, instead start testing with Ruby 2.5.

Various CI fixes
 - Switch to using default-mysql-client apt package while building CI (https://github.com/zendesk/active_record_host_pool/pull/46/)
 - Lock down OS images in tests to fix build (https://github.com/zendesk/active_record_host_pool/pull/45)
 - Switch from Travis to CircleCI (https://github.com/zendesk/active_record_host_pool/pull/39), (https://github.com/zendesk/active_record_host_pool/pull/43)
 - Use ram mysql when testing (https://github.com/zendesk/active_record_host_pool/pull/41)

Rubocop:
 - Update to version 0.62.0 of Rubocop (https://github.com/zendesk/active_record_host_pool/pull/42) 
 - Fix a Security/Eval failure in tests (https://github.com/zendesk/active_record_host_pool/pull/36)

Update ownership of the Gem (https://github.com/zendesk/active_record_host_pool/pull/38)
Update locked gem dependencies (https://github.com/zendesk/active_record_host_pool/pull/37)

### 0.11.0

Drop support for mysql gem, and only support mysql2 (https://github.com/zendesk/active_record_host_pool/pull/35)

Rails compatibility:
 - Test released Rails 5.1 version (https://github.com/zendesk/active_record_host_pool/pull/31)
 - Compatibility with Rails 5.2 (https://github.com/zendesk/active_record_host_pool/pull/32), (https://github.com/zendesk/active_record_host_pool/pull/34)

Upgrade Rubocop (https://github.com/zendesk/active_record_host_pool/pull/33/)

### <= 0.10.1

Unwritten
