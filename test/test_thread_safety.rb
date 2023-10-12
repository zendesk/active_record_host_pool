# frozen_string_literal: true

require_relative "helper"

class ThreadSafetyTest < Minitest::Test
  include ARHPTestSetup

  def setup
    if ActiveRecord::Base.legacy_connection_handling
      Phenix.rise!
    else
      Phenix.rise! config_path: "test/three_tier_database.yml"
    end

    arhp_create_models

    Pool1DbA.create!(val: "test_Pool1DbA_value")
    Pool1DbB.create!(val: "test_Pool1DbB_value")
    Pool2DbD.create!(val: "test_Pool2DbD_value")
  end

  def teardown
    ActiveRecord::Base.connection.disconnect!
    ActiveRecordHostPool::PoolProxy.class_variable_set(:@@_connection_pools, {})
    Phenix.burn!
  end

  def test_main_and_spawned_thread_switch_db_when_querying_same_host
    assert_query_host_1_db_a

    thread = Thread.new do
      assert_query_host_1_db_b

      Thread.current[:done] = true
      sleep

      checkin_connection
    end

    sleep 0.01 until thread[:done]

    assert_query_host_1_db_a

    thread.wakeup
    thread.join
  end

  def test_main_and_spawned_thread_can_query_different_hosts
    assert_query_host_1_db_a

    thread = Thread.new do
      assert_query_host_2_db_d

      Thread.current[:done] = true
      sleep

      checkin_connection
    end

    sleep 0.01 until thread[:done]

    assert_query_host_1_db_a

    thread.wakeup
    thread.join
  end

  def test_threads_can_query_in_parallel
    long_sleep = 0.5
    short_sleep = 0.1

    even_threads_do_this = [
      {method: method(:assert_query_host_1_db_a), db_sleep_time: long_sleep},
      {method: method(:assert_query_host_1_db_b), db_sleep_time: short_sleep}
    ]
    odd_threads_do_this = [
      {method: method(:assert_query_host_1_db_b), db_sleep_time: short_sleep},
      {method: method(:assert_query_host_1_db_a), db_sleep_time: long_sleep}
    ]

    threads = 4.times.map do |n|
      Thread.new do
        Pool1DbA.connection
        Thread.current[:ready] = true
        sleep

        Thread.current.name = "Test thread #{n}"

        what_to_do = n.even? ? even_threads_do_this : odd_threads_do_this

        what_to_do.each do |action|
          action[:method].call(sleep_time: action[:db_sleep_time])
        end

        Thread.current[:done] = true
        sleep

        checkin_connection
      end
    end

    sleep 0.01 until threads.all? { |t| t[:ready] }
    execution_time = Benchmark.realtime do
      threads.each(&:wakeup)
      sleep 0.01 until threads.all? { |t| t[:done] }
    end

    serial_execution_time = 4 * (short_sleep + long_sleep)
    max_expected_time = serial_execution_time * 0.75

    assert_operator(execution_time, :<, max_expected_time)

    threads.each(&:wakeup)
    threads.each(&:join)
  end

  def test_each_thread_has_its_own_connection_and_can_switch
    threads_to_connections = {}

    threads = 3.times.map do |n|
      Thread.new do
        Thread.current.name = "Test thread #{n}"

        threads_to_connections[Thread.current] = []

        assert_query_host_1_db_a
        threads_to_connections[Thread.current].push(Pool1DbA.connection)

        assert_query_host_1_db_b
        threads_to_connections[Thread.current].push(Pool1DbB.connection)

        Thread.current[:done] = true
        sleep
        checkin_connection
      end
    end

    sleep 0.01 until threads.all? { |t| t[:done] }

    # Each thread only saw one connection
    threads_to_connections.each do |_thread, connections|
      assert_equal(1, connections.uniq.length)
      assert_equal(1, connections.map(&:unproxied).uniq.length)
    end

    # Each thread's connection was unique
    connections = threads_to_connections.values.flatten
    assert_equal(3, connections.uniq.length)
    assert_equal(3, connections.map(&:unproxied).uniq.length)

    threads.each(&:wakeup)
    threads.each(&:join)
  end

  def assert_query_host_1_db_a(sleep_time: 0)
    result = Pool1DbA.connection.execute("SELECT val, SLEEP(#{sleep_time}) from tests")
    assert_equal("test_Pool1DbA_value", result.first.first)
  end

  def assert_query_host_1_db_b(sleep_time: 0)
    result = Pool1DbB.connection.execute("SELECT val, SLEEP(#{sleep_time}) from tests")
    assert_equal("test_Pool1DbB_value", result.first.first)
  end

  def assert_query_host_2_db_d(sleep_time: 0)
    result = Pool2DbD.connection.execute("SELECT val, SLEEP(#{sleep_time}) from tests")
    assert_equal("test_Pool2DbD_value", result.first.first)
  end

  def checkin_connection
    ActiveRecord::Base.connection_pool.checkin ActiveRecord::Base.connection
  end
end
