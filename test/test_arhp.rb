# frozen_string_literal: true

require_relative 'helper'

if ActiveRecord.version >= Gem::Version.new('6.1')
  ActiveRecord::Base.legacy_connection_handling = (ENV['LEGACY_CONNECTION_HANDLING'] == 'true')
end

class ActiveRecordHostPoolTest < Minitest::Test
  include ARHPTestSetup
  def setup
    if ActiveRecord.version >= Gem::Version.new('6.1') && !ActiveRecord::Base.legacy_connection_handling
      Phenix.rise! config_path: 'test/three_tier_database.yml'
    else
      Phenix.rise!
    end
    arhp_create_models
  end

  def teardown
    Phenix.burn!
  end

  def test_process_forking_with_connections
    # Ensure we have a connection already
    assert_equal(true, ActiveRecord::Base.connected?)

    # Verify that when we fork, the process doesn't crash
    pid = Process.fork do
      if ActiveRecord.version >= Gem::Version.new('5.2')
        assert_equal(false, ActiveRecord::Base.connected?) # New to Rails 5.2
      else
        assert_equal(true, ActiveRecord::Base.connected?)
      end
    end
    Process.wait(pid)
    # Cleanup any connections we may have left around
    ActiveRecord::Base.connection_handler.clear_all_connections!
  end

  def test_models_with_matching_hosts_ports_sockets_usernames_and_replica_status_should_share_a_connection
    assert_equal(Pool1DbA.connection.raw_connection, Pool1DbB.connection.raw_connection)
    assert_equal(Pool2DbD.connection.raw_connection, Pool2DbE.connection.raw_connection)
  end

  def test_models_with_different_ports_should_not_share_a_connection
    refute_equal(Pool1DbA.connection.raw_connection, Pool2DbD.connection.raw_connection)
  end

  def test_models_with_different_usernames_should_not_share_a_connection
    refute_equal(Pool2DbE.connection.raw_connection, Pool3DbE.connection.raw_connection)
  end

  def test_should_select_on_correct_database
    Pool1DbA.connection.send(:select_all, 'select 1')
    assert_equal 'arhp_test_db_a', current_database(Pool1DbA)

    Pool2DbD.connection.send(:select_all, 'select 1')
    assert_equal 'arhp_test_db_d', current_database(Pool2DbD)

    Pool3DbE.connection.send(:select_all, 'select 1')
    assert_equal 'arhp_test_db_e', current_database(Pool3DbE)
  end

  def test_should_insert_on_correct_database
    Pool1DbA.connection.send(:insert, "insert into tests values(NULL, 'foo')")
    assert_equal 'arhp_test_db_a', current_database(Pool1DbA)

    Pool2DbD.connection.send(:insert, "insert into tests values(NULL, 'foo')")
    assert_equal 'arhp_test_db_d', current_database(Pool2DbD)

    Pool3DbE.connection.send(:insert, "insert into tests values(NULL, 'foo')")
    assert_equal 'arhp_test_db_e', current_database(Pool3DbE)
  end

  def test_connection_returns_a_proxy
    assert_kind_of ActiveRecordHostPool::ConnectionProxy, Pool1DbA.connection
  end

  def test_connection_proxy_handles_private_methods
    # Relies on connection.class returning the real class
    Pool1DbA.connection.class.class_eval do
      private

      def test_private_method
        true
      end
    end
    assert Pool1DbA.connection.respond_to?(:test_private_method, true)
    refute Pool1DbA.connection.respond_to?(:test_private_method)
    assert_includes(Pool1DbA.connection.private_methods, :test_private_method)
    assert_equal true, Pool1DbA.connection.send(:test_private_method)
  end

  def test_should_not_share_a_query_cache
    Pool1DbA.create(val: 'foo')
    Pool1DbB.create(val: 'foobar')
    Pool1DbA.connection.cache do
      refute_equal Pool1DbA.first.val, Pool1DbB.first.val
    end
  end

  def test_object_creation
    Pool1DbA.create(val: 'foo')
    assert_equal('arhp_test_db_a', current_database(Pool1DbA))

    Pool2DbD.create(val: 'bar')
    assert_equal('arhp_test_db_a', current_database(Pool1DbA))
    assert_equal('arhp_test_db_d', current_database(Pool2DbD))

    Pool1DbB.create!(val: 'bar_distinct')
    assert_equal('arhp_test_db_b', current_database(Pool1DbB))
    assert Pool1DbB.find_by_val('bar_distinct')
    refute Pool1DbA.find_by_val('bar_distinct')
  end

  def test_disconnect
    Pool1DbA.create(val: 'foo')
    unproxied = Pool1DbA.connection.unproxied
    Pool1DbA.connection_handler.clear_all_connections!
    Pool1DbA.create(val: 'foo')
    assert(unproxied != Pool1DbA.connection.unproxied)
  end

  def test_checkout
    connection = ActiveRecord::Base.connection_pool.checkout
    assert_kind_of(ActiveRecordHostPool::ConnectionProxy, connection)
    ActiveRecord::Base.connection_pool.checkin(connection)
    c2 = ActiveRecord::Base.connection_pool.checkout
    assert(c2 == connection)
  end

  def test_no_switch_when_creating_db
    conn = Pool1DbA.connection
    conn.expects(:execute_without_switching)
    conn.expects(:_switch_connection).never
    assert conn._host_pool_current_database
    conn.create_database(:some_args, charset: 'utf8mb4')
  end

  def test_no_switch_when_dropping_db
    conn = Pool1DbA.connection
    conn.expects(:execute_without_switching)
    conn.expects(:_switch_connection).never
    assert conn._host_pool_current_database
    conn.drop_database(:some_args)
  end

  def test_underlying_assumption_about_test_db
    debug_me = false
    # ensure connection
    Pool1DbA.first

    # which is the "default" DB to connect to?
    first_db = Pool1DbA.connection.unproxied.instance_variable_get(:@_cached_current_database)
    puts "\nOk, we started on #{first_db}" if debug_me

    switch_to_klass = case first_db
    when 'arhp_test_db_b'
      Pool1DbA
    when 'arhp_test_db_a'
      Pool1DbB
    else
      raise "Expected a database name, got #{first_db.inspect}"
    end
    expected_database = switch_to_klass.connection.instance_variable_get(:@database)

    # switch to the other database
    switch_to_klass.first
    puts "\nAnd now we're on #{current_database(switch_to_klass)}" if debug_me

    # get the current thread id so we can shoot ourselves in the head
    thread_id = switch_to_klass.connection.select_value('select @@pseudo_thread_id')

    # now, disable our auto-switching and trigger a mysql reconnect
    switch_to_klass.connection.unproxied.stubs(:_switch_connection).returns(true)
    Pool2DbD.connection.execute("KILL #{thread_id}")

    # and finally, did mysql reconnect correctly?
    puts "\nAnd now we end up on #{current_database(switch_to_klass)}" if debug_me
    assert_equal expected_database, current_database(switch_to_klass)
  end

  def test_release_connection
    pool = ActiveRecord::Base.connection_pool
    conn = pool.connection
    pool.expects(:checkin).with(conn)
    pool.release_connection
  end
end
