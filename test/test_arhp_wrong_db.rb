# frozen_string_literal: true

require_relative "helper"

class ActiveRecordHostPoolWrongDBTest < Minitest::Test
  include ARHPTestSetup

  def setup
    ActiveRecordHostPool::PoolProxy.class_variable_set(:@@_connection_pools, {})
  end

  def teardown
    ActiveRecordHostPool::PoolProxy.class_variable_set(:@@_connection_pools, {})
  end

  # rake db:create uses a pattern where it tries to connect to a non-existent database.
  # but then we had this left in the connection pool cache.
  def test_connecting_to_wrong_db_first
    reached_first_exception = false
    reached_second_exception = false

    begin
      eval(<<-RUBY, binding, __FILE__, __LINE__ + 1)
        class TestNotThere < ActiveRecord::Base
          config = ActiveRecord::Base.configurations.find_db_config("test_pool_3_db_e").configuration_hash.dup
          config[:database] = "some_nonexistent_database"
          establish_connection(config)
        end

        TestNotThere.connection.execute("SELECT 1")
      RUBY
    rescue => e
      assert_match(/(Unknown database|We could not find your database:|Database not found:) '?some_nonexistent_database/, e.message)
      reached_first_exception = true
    end

    assert reached_first_exception

    config = ActiveRecord::Base.configurations.find_db_config("test_pool_3_db_e").configuration_hash.dup
    config[:database] = "a_different_nonexistent_database"
    TestNotThere.establish_connection(config)

    begin
      TestNotThere.connection.execute("SELECT 1")
    rescue => e
      # If the pool is caching a bad connection, that connection will be used instead
      # of the intended connection.
      refute_match(/(Unknown database|We could not find your database:|Database not found:) '?some_nonexistent_database/, e.message)
      assert_match(/(Unknown database|We could not find your database:|Database not found:) '?a_different_nonexistent_database/, e.message)
      reached_second_exception = true
    end

    assert reached_second_exception
  end
end
