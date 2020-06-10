# frozen_string_literal: true

require_relative 'helper'

class ActiveRecordHostPoolTest < Minitest::Test
  include ARHPTestSetup

  def setup
    Phenix.rise!
    arhp_create_models
    change_databases_across_two_threads
  end

  def teardown
    Phenix.burn!
  end

  # When the implementation is not thread-safe the below query will try to execute the query on the
  # "some_other_database" which doesn't exist and this will blow up.
  def test_executing_query_is_not_impacted_by_another_thread_switching_databases
    connection.execute('select count(*) from tests')
  end

  # Sanity check that the databases in use per thread are distinct.
  def test_databases_are_thread_local
    assert_equal 'arhp_test_1', database_values.database_in_use_on_main_thread
    assert_equal 'some_other_database', database_values.database_in_use_on_child_thread
  end

  def test_connection_adapter_internal_database_is_thread_local
    assert_equal 'arhp_test_1', database_values.database_config_in_use_on_main_thread
    assert_equal 'some_other_database', database_values.database_config_on_child_thread
  end

  private

  def connection
    @connection ||= Test1.connection.unproxied
  end

  def database_values
    @database_values ||= OpenStruct.new(
      database_in_use_on_child_thread: nil,
      database_config_on_child_thread: nil,
      database_in_use_on_main_thread: nil,
      database_config_on_main_thread: nil
    )
  end

  def change_databases_across_two_threads
    connection._host_pool_current_database = 'arhp_test_1'

    thread = Thread.new do
      connection._host_pool_current_database = 'some_other_database'

      # Stop this thread and recede control to the main thread. It will
      # wakeup this thread when it's time to move on.
      Thread.stop

      database_values.database_in_use_on_child_thread = connection._host_pool_current_database
      database_values.database_config_on_child_thread = connection.instance_eval { @config[:database] }
    end

    # Wait for the thread to stop to control execution steps
    next until thread.stop?

    database_values.database_in_use_on_main_thread = connection._host_pool_current_database
    database_values.database_config_in_use_on_main_thread = connection.instance_eval { @config[:database] }

    thread.wakeup
    thread.join
  end
end
