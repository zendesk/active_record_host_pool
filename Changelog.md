# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and as of v1.0.0 this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Moved `select_db` inside of the `with_raw_connection` block of the `#raw_execute` method. This should allow for using Rails' built-in reconnect & retry logic with the Trilogy adapter or Rails 7.1+.
- In Rails 7.1+, when a new ConnectionProxy is instantiated the database switch is lazily triggered by the subsequent database query instead of immediately.

### Removed
- Calling `#clean!` and `#verified!` on connections because it is no longer necessary.

## [3.2.0]

### Added
- Calls `#verified!` on the connection after `#clean!`.

## [3.1.1]

### Fixed
- A typo causing `#clean!` to not run. 

## [3.1.0]

### Added
- Calls `#clean!` on the connection after switching databases.

## [3.0.0]

### Added
- Support and testing for Rails 7.2 & Rails main.

### Removed
- Support for ActiveRecord's legacy connection handling.

## [2.2.0]

### Removed
- Support for Ruby 3.0.

### Added
- Rails 6.1 testing with Trilogy.

### Fixed
- Fixed using ActiveRecordHostPool and the `activerecord-trilogy-adapter v3.1+`.

### Changed
-  ActiveRecordHostPool will now raise an exception if you try to use a version of `activerecord-trilogy-adapter < 3.1`.

## [2.1.0]

### Changed
- ActiveRecordHostPool now uses prepend to patch `#execute`, `#raw_execute`, `#drop_database`, `#create_database`, and `#disconnect!`. Prepending is incompatible when also using `alias` or `alias_method` to patch those methods; avoid aliasing them to prevent an infinite loop.

### Removed
- Dropped support for Ruby 2.7.x.

## [2.0.0]

### Added
- Add support for Rails 7.1.
- `Trilogy` is now a supported MySQL database adapter. ActiveRecordHostPool no longer requires `mysql2`, nor does it explicitly require `activerecord-trilogy-adapter`. Applications using ARHP will now need to explicitly require one of these adapters in its gemfile. When using `activerecord-trilogy-adapter` also ensure that the `trilogy` gem is locked to `v2.5.0+`.

### Removed
- Remove `mysql2` as a direct dependency, test Rails 7.0 with `mysql2` and `activerecord-trilogy-adapter`.
- Remove support for Rails 5.1, 5.2, and 6.0.

### Fixed
- Implement equality for connection proxies to consider database; allows fixture loading for different databases

## [1.2.5] - 2023-07-14
### Added
- Start testing with Ruby 3.2.

### Removed
- Drop Ruby 2.6.

### Fixed
- Use a mutex inside `PoolProxy#disconnect!`. This might fix some `ActiveRecord::ConnectionNotEstablished` issues when a multi-threaded application is under heavy load. (Only applies when using Rails 6.1 or newer).

## [1.2.4] - 2023-03-20
### Fixed
- Fixed the warning when using `ruby2_keywords` on `execute_with_switching`.
- Simplified the `clear_query_caches_for_current_thread` patch.

## [1.2.3] - 2023-01-19
### Fixed
- Fix the patch for `ActiveRecord::Base.clear_query_caches_for_current_thread` to work correctly right after the creation of a new connection pool. (https://github.com/zendesk/active_record_host_pool/pull/105)

## [1.2.2] - 2023-01-18
### Added
- Add a new `ActiveRecordHostPool::PoolProxy#_unproxied_connection` method which gives access to the underlying, "real", shared connection without going through the connection proxy, which would call `#_host_pool_current_database=` on the underlying connection. (https://github.com/zendesk/active_record_host_pool/pull/104)

### Fixed
- Fix the patch for `ActiveRecord::Base.clear_on_handler` to work correctly right after the creation of a new connection pool. (https://github.com/zendesk/active_record_host_pool/pull/104)

## [1.2.1] - 2022-12-23
### Fixed
- Fix forwarding of kwargs when calling `#execute` in Rails 7. (https://github.com/zendesk/active_record_host_pool/pull/101)

## [1.2.0] - 2022-10-13
### Added
- Support for Rails 7.0 with [legacy_connection_handling=false and legacy_connection_handling=true](https://github.com/zendesk/active_record_host_pool/pull/95)
- Start testing with Ruby 3.0 & 3.1

## [1.1.1] - 2022-08-26
### Fixed
- Ensure that recently added files "lib/active_record_host_pool/pool_proxy_6_1.rb" and "lib/active_record_host_pool/pool_proxy_legacy.rb" are built into the shipped gem. (https://github.com/zendesk/active_record_host_pool/pull/92)

## [1.1.0] - 2022-08-26
### Added
- Support for Rails 6.1 with [legacy_connection_handling=false](https://github.com/zendesk/active_record_host_pool/pull/90) and [legacy_connection_handling=true](https://github.com/zendesk/active_record_host_pool/pull/88)

### Removed
- Removed compatibility with Rails 4.2. (https://github.com/zendesk/active_record_host_pool/pull/71)
- Removed compatibility with Ruby 2.5 and lower. (https://github.com/zendesk/active_record_host_pool/pull/80)

## [1.0.3] - 2021-02-09
### Fixed
- Add missing file to the released gem. (https://github.com/zendesk/active_record_host_pool/pull/68)

## [1.0.2] - 2021-02-09
### Fixed
- Fix unintended connection switching while clearing query cache in Rails 6.0. (https://github.com/zendesk/active_record_host_pool/pull/61)

## [1.0.1] - 2020-03-30
### Fixed
- Fix connection leakage when calling `release_connection` on pre-Rails 5 applications. (https://github.com/zendesk/active_record_host_pool/pull/58)

## [1.0.0] - 2020-02-25
### Added
- Support for Rails 6.0.x. (https://github.com/zendesk/active_record_host_pool/pull/53)

### Changed
- This gem now adheres to semantic versioning.

## [0.13.0] - 2019-08-26
### Added
- Support for Rails 5.2.3. (https://github.com/zendesk/active_record_host_pool/pull/48)

### Removed
- Removed testing with EOL Ruby 2.3 (https://github.com/zendesk/active_record_host_pool/pull/49)

## [0.12.0] - 2019-08-21
### Added
- Start testing with Ruby 2.5
- Update Gem ownership (https://github.com/zendesk/active_record_host_pool/pull/38)

### Removed
- Removed compatibility with Rails 3.2 and lower.
- Removed compatibility with Rails 5.0.
- Stop testing with Ruby 2.2.

## [0.11.0] - 2018-04-24
### Added
- Compatibility with Rails 5.1 (https://github.com/zendesk/active_record_host_pool/pull/31)
- Compatibility with Rails 5.2 (https://github.com/zendesk/active_record_host_pool/pull/32), (https://github.com/zendesk/active_record_host_pool/pull/34)

### Removed
- Removed support for the mysql gem, and only support mysql2 (https://github.com/zendesk/active_record_host_pool/pull/35)

## <= [0.10.1]

Unwritten
