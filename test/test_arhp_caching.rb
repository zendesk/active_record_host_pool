# frozen_string_literal: true

require_relative 'helper'

class ActiveRecordHostCachingTest < Minitest::Test
  include ARHPTestSetup
  def setup
    if RAILS_6_1_WITH_NON_LEGACY_CONNECTION_HANDLING
      Phenix.rise! config_path: 'test/three_tier_database.yml'
    else
      Phenix.rise!
    end
    arhp_create_models
  end

  def teardown
    ActiveRecord::Base.connection.disconnect!
    ActiveRecordHostPool::PoolProxy.class_variable_set(:@@_connection_pools, {})
    Phenix.burn!
  end

  def test_should_not_share_a_query_cache
    if ActiveRecord.version >= Gem::Version.new('6.0')
      ActiveRecord::Base.clear_query_caches_for_current_thread
    end

    Pool1DbA.create(val: 'foo')
    Pool1DbB.create(val: 'foobar')

    Pool1DbA.connection.cache do
      refute_equal Pool1DbA.first.val, Pool1DbB.first.val
    end
  end

  if ActiveRecord.version >= Gem::Version.new('6.0')
    def test_models_with_matching_hosts_and_non_matching_databases_issue_exists_without_arhp_patch
      simulate_rails_app_active_record_railties

      # Remove patch that fixes an issue in Rails 6+ to ensure it still
      # exists. If this begins to fail then it may mean that Rails has fixed
      # the issue so that it no longer occurs.
      without_module_patch(ActiveRecordHostPool::ClearQueryCachePatch, :clear_query_caches_for_current_thread) do
        exception = assert_raises(ActiveRecord::StatementInvalid) do
          ActiveRecord::Base.cache { Pool1DbC.create! }
        end

        cached_db = Pool1DbC.connection.unproxied.pool.connections.first.instance_variable_get(:@_cached_current_database)
        assert_equal("Mysql2::Error: Table '#{cached_db}.pool1_db_cs' doesn't exist", exception.message)
      end
    end

    def test_models_with_matching_hosts_and_non_matching_databases_do_not_mix_up_underlying_database
      simulate_rails_app_active_record_railties
      # ActiveRecord will clear the query cache after any action that dirties the cache (create, update, etc)
      # Because we're testing the patch we want to ensure it runs at least once
      ActiveRecord::Base.clear_query_caches_for_current_thread

      # ActiveRecord 6.0 introduced a change that surfaced a problematic code
      # path in active_record_host_pool when clearing caches across connection
      # handlers which can cause the database to change.
      # See ActiveRecordHostPool::ClearQueryCachePatch
      ActiveRecord::Base.cache { Pool1DbC.create! }
    end
  end
end
