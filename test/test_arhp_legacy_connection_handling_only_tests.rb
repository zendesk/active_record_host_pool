# frozen_string_literal: true

require_relative "helper"

if LEGACY_CONNECTION_HANDLING
  class ActiveRecordHostPoolLegacyConnectiongHandlingTest < Minitest::Test
    include ARHPTestSetup
    def setup
      Phenix.rise!
      arhp_create_models
    end

    def teardown
      ActiveRecord::Base.connection.disconnect!
      ActiveRecordHostPool::PoolProxy.class_variable_set(:@@_connection_pools, {})
      Phenix.burn!
    end

    def test_models_without_matching_replica_status_should_not_share_a_connection
      refute_equal(Pool1DbA.connection.raw_connection, Pool1DbAReplica.connection.raw_connection)
    end

    def test_models_with_matching_hosts_and_non_matching_databases_should_share_a_connection
      simulate_rails_app_active_record_railties
      assert_equal(Pool1DbA.connection.raw_connection, Pool1DbC.connection.raw_connection)
    end

    def test_shards_and_non_shards_should_not_share_a_connection
      refute_equal(Pool1DbA.connection.raw_connection, Pool1DbShard.connection.raw_connection)
    end
  end
end
