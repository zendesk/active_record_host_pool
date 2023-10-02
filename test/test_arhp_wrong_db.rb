# frozen_string_literal: true

require_relative "helper"

class ActiveRecordHostPoolWrongDBTest < Minitest::Test
  include ARHPTestSetup
  def setup
    if LEGACY_CONNECTION_HANDLING
      Phenix.load_database_config
    else
      Phenix.load_database_config "test/three_tier_database.yml"
    end
  end

  def teardown
    ActiveRecordHostPool::PoolProxy.class_variable_set(:@@_connection_pools, {})
    Phenix.burn!
  end

  # rake db:create uses a pattern where it tries to connect to a non-existant database.
  # but then we had this left in the connection pool cache.
  def test_connecting_to_wrong_db_first
    reached_first_exception = false
    reached_second_exception = false

    begin
      eval(<<-RUBY, binding, __FILE__, __LINE__ + 1)
        class TestNotThere < ActiveRecord::Base
          establish_connection(:test_pool_1_db_not_there)
          connection
        end
      RUBY
    rescue => e
      assert_match(/(Unknown database|We could not find your database:) '?arhp_test_db_not_there/, e.message)
      reached_first_exception = true
    end

    assert reached_first_exception

    TestNotThere.establish_connection(:test_pool_1_db_a)

    begin
      TestNotThere.connection
    rescue => e
      # If the pool is caching a bad connection, that connection will be used instead
      # of the intended connection.
      refute_match(/(Unknown database|We could not find your database:) '?arhp_test_db_not_there/, e.message)
      assert_match(/(Unknown database|We could not find your database:) '?arhp_test_db_a/, e.message)
      reached_second_exception = true
    end

    assert reached_second_exception
  end
end
