# frozen_string_literal: true

require_relative "helper"

class ActiveRecordHostCachingTest < Minitest::Test
  include ARHPTestSetup
  def setup
    if LEGACY_CONNECTION_HANDLING
      Phenix.rise!
    else
      Phenix.rise! config_path: "test/three_tier_database.yml"
    end
    arhp_create_models
  end

  def teardown
    ActiveRecord::Base.connection.disconnect!
    ActiveRecordHostPool::PoolProxy.class_variable_set(:@@_connection_pools, {})
    Phenix.burn!
  end

  def test_should_not_share_a_query_cache
    ActiveRecord::Base.clear_query_caches_for_current_thread

    Pool1DbA.create(val: "foo")
    Pool1DbB.create(val: "foobar")

    Pool1DbA.connection.cache do
      refute_equal Pool1DbA.first.val, Pool1DbB.first.val
    end
  end

  def test_models_with_matching_hosts_and_non_matching_databases_issue_exists_without_arhp_patch
    simulate_rails_app_active_record_railties

    # Reset the connections post-setup so that we ensure the last DB isn't arhp_test_db_c
    ActiveRecord::Base.connection.discard!
    ActiveRecordHostPool::PoolProxy.class_variable_set(:@@_connection_pools, {})
    ActiveRecord::Base.establish_connection(:test_pool_1_db_a)

    # Ensure this works _with_ the patch
    ActiveRecord::Base.cache { Pool1DbC.create! }

    # Remove patch that fixes an issue in Rails 6+ to ensure it still
    # exists. If this begins to fail then it may mean that Rails has fixed
    # the issue so that it no longer occurs.
    case "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"
    when "7.1"
      mod = ActiveRecordHostPool::ClearQueryCachePatch
      method_to_remove = :clear_query_caches_for_current_thread
    when "6.1", "7.0"
      mod = ActiveRecordHostPool::ClearOnHandlerPatch
      method_to_remove = :clear_on_handler
    end

    without_module_patch(mod, method_to_remove) do
      exception = assert_raises(ActiveRecord::StatementInvalid) do
        ActiveRecord::Base.cache { Pool1DbC.create! }
      end

      cached_db = Pool1DbC.connection.unproxied.pool.connections.first.instance_variable_get(:@_cached_current_database)

      case ActiveRecordHostPool.loaded_db_adapter
      when :mysql2
        assert_equal("Mysql2::Error: Table '#{cached_db}.pool1_db_cs' doesn't exist", exception.message)
      when :trilogy
        assert_equal("Trilogy::ProtocolError: 1146: Table '#{cached_db}.pool1_db_cs' doesn't exist", exception.message)
      end
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
