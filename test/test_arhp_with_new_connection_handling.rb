# frozen_string_literal: true

require_relative 'helper'

if ActiveRecord.version >= Gem::Version.new('6.1') && !ActiveRecord::Base.legacy_connection_handling
  class ActiveRecordHostPoolTestWithNewConnectionHandling < Minitest::Test
    include ARHPTestSetup
    def setup
      Phenix.rise! config_path: 'test/three_tier_database.yml'
      arhp_create_models
    end

    def teardown
      Phenix.burn!
    end

    def test_models_with_matching_hosts_and_non_matching_databases_issue_exists_without_arhp_patch
      # Remove patch that fixes an issue in Rails 6+ to ensure it still
      # exists. If this begins to fail then it may mean that Rails has fixed
      # the issue so that it no longer occurs.
      without_module_patch(ActiveRecordHostPool::ClearQueryCachePatch, :clear_query_caches_for_current_thread) do
        without_module_patch(ActiveRecordHostPool::ClearQueryCachePatch, :clear_on_handler) do
          exception = assert_raises(ActiveRecord::StatementInvalid) do
            ActiveRecord::Base.establish_connection(:test_pool_1_db_a)
            ActiveRecord::Base.cache { Pool1DbC.create! }
          end

          assert_equal("Mysql2::Error: Table 'arhp_test_db_a.pool1_db_cs' doesn't exist", exception.message)
        end
      end
    end

    def test_models_with_matching_hosts_and_non_matching_databases_do_not_mix_up_underlying_database
      # ActiveRecord 6.0 introduced a change that surfaced a problematic code
      # path in active_record_host_pool when clearing caches across connection
      # handlers which can cause the database to change.
      # See ActiveRecordHostPool::ClearQueryCachePatch
      ActiveRecord::Base.cache { Pool1DbC.create! }
    end

    def test_correctly_writes_to_sharded_databases
      AbstractShardedModel.connected_to(role: :writing, shard: :shard_b) do
        ShardedModel.create!
      end

      AbstractShardedModel.connected_to(role: :writing, shard: :shard_d) do
        ShardedModel.create!
      end

      records_on_shard_b = AbstractShardedModel.connected_to(role: :writing, shard: :shard_b) do
        ShardedModel.count
      end
      records_on_shard_d = AbstractShardedModel.connected_to(role: :writing, shard: :shard_d) do
        ShardedModel.count
      end

      assert_equal 1, records_on_shard_b
      assert_equal 1, records_on_shard_d
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

    def test_reading_and_writing_roles_should_not_share_a_connection
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
