require File.expand_path('helper', File.dirname(__FILE__))

class ActiveRecordHostPoolWrongDBTest < MiniTest::Unit::TestCase
  include ARHPTestSetup
  def setup
    ActiveRecordHostPool::PoolProxy.class_variable_set(:@@_connection_pools, {})
  end

  # rake db:create uses a pattern where it tries to connect to a non-existant database.
  # but then we had this left in the connection pool cache.
  def test_connecting_to_wrong_db_first
    reached_first_exception = false
    reached_second_exception = false

    begin
      eval <<-EOC
        class TestNotThere < ActiveRecord::Base
          establish_connection(:test_host_1_db_not_there)
          connection
        end
      EOC
    rescue Exception => e
      assert e.message =~ /Unknown database 'arhp_test_no_create'/
      reached_first_exception = true
    end

    assert reached_first_exception

    TestNotThere.establish_connection(:test_host_1_db_1)

    begin
      TestNotThere.connection
    rescue Exception => e
      # If the pool is caching a bad connection, that connection will be used instead
      # of the intended connection.
      assert e.message !~ /Unknown database 'arhp_test_no_create'/
      assert e.message =~ /Unknown database 'arhp_test_1'/
      reached_second_exception = true
    end

    assert reached_second_exception
  end
end
