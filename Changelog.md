# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and as of v1.0.0 this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
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
