# frozen_string_literal: true

require_relative 'helper'

if RAILS_6_1_WITH_NON_LEGACY_CONNECTION_HANDLING
  class ActiveRecordHostPoolTestWithNonlegacyConnectionHandling < Minitest::Test
    include ARHPTestSetup
    def setup
      Phenix.rise! config_path: 'test/three_tier_database.yml'
      arhp_create_models
    end

    def teardown
      ActiveRecord::Base.connection.disconnect!
      ActiveRecordHostPool::PoolProxy.class_variable_set(:@@_connection_pools, {})
      Phenix.burn!
    end

    def test_correctly_writes_to_sharded_databases
      AbstractShardedModel.connected_to(role: :writing, shard: :shard_b) do
        ShardedModel.create!
        ShardedModel.create!

        AbstractShardedModel.connected_to(role: :writing, shard: :shard_c) do
          ShardedModel.create!
        end

        ShardedModel.create!
      end

      AbstractShardedModel.connected_to(role: :writing, shard: :shard_d) do
        ShardedModel.create!
        ShardedModel.create!
      end

      # Normally we would count the records using the replicas (`reading` role).
      # However, ActiveRecord does not mirror data from the writing DB onto the
      # replica database(s) for you so apps must implement that themselves.
      # Therefore, for testing purposes, we count the records on the writer db.
      records_on_shard_b = AbstractShardedModel.connected_to(role: :writing, shard: :shard_b) do
        ShardedModel.count
      end

      records_on_shard_c = AbstractShardedModel.connected_to(role: :writing, shard: :shard_c) do
        ShardedModel.count
      end

      records_on_shard_d = AbstractShardedModel.connected_to(role: :writing, shard: :shard_d) do
        ShardedModel.count
      end

      assert_equal [3, 1, 2], [records_on_shard_b, records_on_shard_c, records_on_shard_d]
      assert_equal 0, ShardedModel.count
    end

    def test_shards_with_matching_hosts_ports_sockets_usernames_and_replica_status_should_share_a_connection
      default_shard_connection = ShardedModel.connection.raw_connection
      pool_1_shard_b_writing_connection = AbstractShardedModel.connected_to(role: :writing, shard: :shard_b) do
        ShardedModel.connection.raw_connection
      end
      pool_1_shard_b_reading_connection = AbstractShardedModel.connected_to(role: :reading, shard: :shard_b) do
        ShardedModel.connection.raw_connection
      end
      pool_1_shard_c_reading_connection = AbstractShardedModel.connected_to(role: :reading, shard: :shard_c) do
        ShardedModel.connection.raw_connection
      end

      assert_equal(default_shard_connection, pool_1_shard_b_writing_connection)
      assert_equal(pool_1_shard_b_reading_connection, pool_1_shard_c_reading_connection)
    end

    def test_shards_without_matching_ports_should_not_share_a_connection
      default_shard_connection = ShardedModel.connection.raw_connection
      pool_1_shard_b_writing_connection = AbstractShardedModel.connected_to(role: :writing, shard: :shard_b) do
        ShardedModel.connection.raw_connection
      end
      pool_2_shard_d_writing_connection = AbstractShardedModel.connected_to(role: :writing, shard: :shard_d) do
        ShardedModel.connection.raw_connection
      end

      refute_equal(default_shard_connection, pool_2_shard_d_writing_connection)
      refute_equal(pool_1_shard_b_writing_connection, pool_2_shard_d_writing_connection)
    end

    # The role name for a writer database is :writing
    # The role name for a replica/reader database is :reading
    def test_writers_should_not_share_a_connection_with_replicas
      refute_equal(
        (AbstractPool1DbA.connected_to(role: :writing) { Pool1DbA.connection.raw_connection }),
        (AbstractPool1DbA.connected_to(role: :reading) { Pool1DbA.connection.raw_connection })
      )
    end

    def test_sharded_reading_and_writing_roles_should_not_share_a_connection
      shard_c_writing_connection = AbstractShardedModel.connected_to(role: :writing, shard: :shard_c) do
        ShardedModel.connection.raw_connection
      end
      shard_c_reading_connection = AbstractShardedModel.connected_to(role: :reading, shard: :shard_c) do
        ShardedModel.connection.raw_connection
      end

      refute_equal(shard_c_writing_connection, shard_c_reading_connection)
    end

    def test_sharded_reading_roles_without_matching_ports_should_not_share_a_connection
      shard_c_reading_connection = AbstractShardedModel.connected_to(role: :reading, shard: :shard_c) do
        ShardedModel.connection.raw_connection
      end
      shard_d_reading_connection = AbstractShardedModel.connected_to(role: :reading, shard: :shard_d) do
        ShardedModel.connection.raw_connection
      end

      refute_equal(shard_c_reading_connection, shard_d_reading_connection)
    end
  end
end
