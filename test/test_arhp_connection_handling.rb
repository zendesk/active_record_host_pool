# frozen_string_literal: true

require_relative "helper"
require "stringio"

class ActiveRecordHostPoolTestWithNonlegacyConnectionHandling < Minitest::Test
  include ARHPTestSetup

  def teardown
    delete_all_records
    ActiveRecord::Base.connection.disconnect!
    ActiveRecordHostPool::PoolProxy.class_variable_set(:@@_connection_pools, {})
  end

  def test_correctly_writes_to_sharded_databases_and_only_switches_dbs_when_necessary
    # shard_a, shard_b, and shard_c each share the same connection pool and thus the same connection.
    # shard_d is on a separate connection_pool (and connection) than shard_a, shard_b, shard_c.
    # To ensure the db switches remain consistent, we want to set the current database for each connection
    # to a known database before running our assertions.
    AbstractShardedModel.connected_to(role: :writing, shard: :shard_c) { ShardedModel.count }
    AbstractShardedModel.connected_to(role: :writing, shard: :shard_d) { ShardedModel.count }

    # Now that we have switched each connection to a known database, we want to start logging any
    # subsequent database switches to test that we only switch when expected.
    old_logger = ActiveRecord::Base.logger
    new_logger = StringIO.new
    ActiveRecord::Base.logger = Logger.new(new_logger)

    # This connection pool should currently be connected to shard_c and thus a switch to
    # shard_b should occur.
    AbstractShardedModel.connected_to(role: :writing, shard: :shard_b) do
      ShardedModel.create!
      ShardedModel.create!

      # A switch to shard_c should occur.
      AbstractShardedModel.connected_to(role: :writing, shard: :shard_c) do
        ShardedModel.create!
      end

      # A switch back to shard_b should occur.
      ShardedModel.create!
    end

    # This connection pool was previously connected to shard_d, so no switch
    # should occur.
    AbstractShardedModel.connected_to(role: :writing, shard: :shard_d) do
      ShardedModel.create!
      ShardedModel.create!
    end

    # Assert that we switched, and only switched, in the order we expected.
    # If this assertion starts to fail, Rails is likely calling `#connection`
    # somewhere new, and we should investigate
    db_switches = new_logger.string.scan(/select_db (\w+)/).flatten
    assert_equal ["arhp_test_db_shard_b", "arhp_test_db_shard_c", "arhp_test_db_shard_b"], db_switches

    new_logger.string = +""

    # Normally we would count the records using the replicas (`reading` role).
    # However, ActiveRecord does not mirror data from the writing DB onto the
    # replica database(s) for you so apps must implement that themselves.
    # Therefore, for testing purposes, we count the records on the writer db.

    # The last database connected to on this pool was shard_b, so no switch should occur.
    records_on_shard_b = AbstractShardedModel.connected_to(role: :writing, shard: :shard_b) do
      ShardedModel.count
    end

    # A switch to shard_c should occur.
    records_on_shard_c = AbstractShardedModel.connected_to(role: :writing, shard: :shard_c) do
      ShardedModel.count
    end

    # This pool is still connected to shard_d, so no switch should occur.
    records_on_shard_d = AbstractShardedModel.connected_to(role: :writing, shard: :shard_d) do
      ShardedModel.count
    end

    # If this assertion starts to fail, Rails is likely calling `#connection`
    # somewhere new, and we should investigate.
    db_switches = new_logger.string.scan(/select_db (\w+)/).flatten
    assert_equal ["arhp_test_db_shard_c"], db_switches

    assert_equal [3, 1, 2], [records_on_shard_b, records_on_shard_c, records_on_shard_d]
    assert_equal 0, ShardedModel.count
  ensure
    ActiveRecord::Base.logger = old_logger
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
