# frozen_string_literal: true

require_relative "helper"

class ActiveRecordHostPoolTest < Minitest::Test
  include ARHPTestSetup
  def setup
    Phenix.rise! config_path: "test/three_tier_database.yml"
  end

  def teardown
    ActiveRecord::Base.connection.disconnect!
    ActiveRecordHostPool::PoolProxy.class_variable_set(:@@_connection_pools, {})
    Phenix.burn!
  end

  def test_process_forking_with_connections
    # Ensure we have a connection already
    assert_equal(true, ActiveRecord::Base.connected?)

    # Verify that when we fork, the process doesn't crash
    pid = Process.fork do
      refute ActiveRecord::Base.connected?
    end
    Process.wait(pid)
    # Cleanup any connections we may have left around
    ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
  end

  def test_switching_databases_on_the_same_pool_produces_a_clean_connection
    skip unless Pool1DbA.connection.respond_to?(:clean!)

    unproxied_connection = Pool1DbA.connection.unproxied

    # Clean and verify the connection before we end up calling `raw_connection.select_db` again.
    # We want to ensure that the connection stays clean and verified.
    Pool1DbA.connection.clean!
    Pool1DbA.connection.send(:verified!)

    unproxied_connection.stub :verify!, -> { raise "`verify!` should not get called again" } do
      assert(Pool1DbB.connection.unproxied.instance_variable_get(:@verified))
      refute(Pool1DbB.connection.unproxied.instance_variable_get(:@raw_connection_dirty))
    end
  end

  def test_active_record_does_not_reconnect_and_retry_if_allow_retry_is_false
    # Ensure we're connected to the database.
    Pool1DbA.connection.execute("select 1")
    # We use `instance_variable_get(:@raw_connection)` because the `#raw_connection` method "dirties" the connection.
    # If a connection is "dirty" then Rails won't retry.
    raw_connection = Pool1DbA.connection.unproxied.instance_variable_get(:@raw_connection)

    # Stub `#select_db` on the current raw connection to raise an exception.
    raw_connection.stub(:select_db, proc { raise ActiveRecord::ConnectionFailed }) do
      # We use Pool1DbB here because it shares a real connection with Pool1DbA and given that we're currently
      # connected to DbA we will be forced to call `select_db`.
      assert_raises(ActiveRecord::ConnectionFailed) { Pool1DbB.connection.execute("select 1", allow_retry: false) }
    end

    # Rails should not have reconnected to the database.
    assert_same(raw_connection, Pool1DbB.connection.unproxied.instance_variable_get(:@raw_connection))
  end

  def test_passing_allow_retry_will_reconnect_and_retry_when_a_connection_error_is_raised
    # Ensure we're connected to the database.
    Pool1DbA.connection.execute("select 1")
    # We use `instance_variable_get(:@raw_connection)` so that we don't "dirty" the connection.
    # If a connection is "dirty" then Rails won't retry.
    raw_connection = Pool1DbA.connection.unproxied.instance_variable_get(:@raw_connection)

    # Stub `#select_db` on the current raw connection to raise an exception.
    raw_connection.stub(:select_db, proc { raise ActiveRecord::ConnectionFailed }) do
      # We use Pool1DbB here because it shares a real connection with Pool1DbA and given that we're currently
      # connected to DbA we will be forced to call `select_db`.
      Pool1DbB.connection.execute("select 1", allow_retry: true)
    end

    # Rails should have reconnected to the database, giving us a new raw connection.
    refute_same(raw_connection, Pool1DbB.connection.unproxied.instance_variable_get(:@raw_connection))
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
    Pool1DbA.connection.send(:select_all, "select 1")
    assert_equal "arhp_test_db_a", current_database(Pool1DbA)

    Pool2DbD.connection.send(:select_all, "select 1")
    assert_equal "arhp_test_db_d", current_database(Pool2DbD)

    Pool3DbE.connection.send(:select_all, "select 1")
    assert_equal "arhp_test_db_e", current_database(Pool3DbE)
  end

  def test_should_insert_on_correct_database
    Pool1DbA.connection.send(:insert, "insert into tests values(NULL, 'foo')")
    assert_equal "arhp_test_db_a", current_database(Pool1DbA)

    Pool2DbD.connection.send(:insert, "insert into tests values(NULL, 'foo')")
    assert_equal "arhp_test_db_d", current_database(Pool2DbD)

    Pool3DbE.connection.send(:insert, "insert into tests values(NULL, 'foo')")
    assert_equal "arhp_test_db_e", current_database(Pool3DbE)
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

  def test_connection_proxy_equality
    # Refer to same underlying connection and same database
    assert_same Pool1DbA.connection.raw_connection, Pool1DbAOther.connection.raw_connection
    assert Pool1DbA.connection == Pool1DbAOther.connection
    assert Pool1DbA.connection.eql?(Pool1DbAOther.connection)
    assert_equal Pool1DbA.connection.hash, Pool1DbAOther.connection.hash

    # Refer to same underlying connection but with a different database
    assert_same Pool1DbA.connection.raw_connection, Pool1DbB.connection.raw_connection
    refute Pool1DbA.connection == Pool1DbB.connection
    refute Pool1DbA.connection.eql?(Pool1DbB.connection)
    refute_equal Pool1DbA.connection.hash, Pool1DbB.connection.hash
  end

  def test_object_creation
    Pool1DbA.create(val: "foo")
    assert_equal("arhp_test_db_a", current_database(Pool1DbA))

    Pool2DbD.create(val: "bar")
    assert_equal("arhp_test_db_a", current_database(Pool1DbA))
    assert_equal("arhp_test_db_d", current_database(Pool2DbD))

    Pool1DbB.create!(val: "bar_distinct")
    assert_equal("arhp_test_db_b", current_database(Pool1DbB))
    assert Pool1DbB.find_by_val("bar_distinct")
    refute Pool1DbA.find_by_val("bar_distinct")
  end

  def test_disconnect
    Pool1DbA.create(val: "foo")
    unproxied = Pool1DbA.connection.unproxied
    Pool1DbA.connection_handler.clear_all_connections!(:writing)
    Pool1DbA.create(val: "foo")
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
    assert_called(conn, :raw_execute) do
      refute_called(conn, :_switch_connection) do
        assert conn._host_pool_desired_database
        conn.create_database(:some_args)
      end
    end
  end

  def test_no_switch_when_dropping_db
    conn = Pool1DbA.connection
    assert_called(conn, :raw_execute) do
      refute_called(conn, :_switch_connection) do
        assert conn._host_pool_desired_database
        conn.drop_database(:some_args)
      end
    end
  end

  def test_underlying_assumption_about_test_db
    # I am not sure how reconnection works with Trilogy
    skip if ActiveRecordHostPool.loaded_db_adapter == :trilogy

    debug_me = false
    # ensure connection
    Pool1DbA.first

    # which is the "default" DB to connect to?
    first_db = Pool1DbA.connection.unproxied.instance_variable_get(:@_cached_current_database)
    puts "\nOk, we started on #{first_db}" if debug_me

    switch_to_klass = case first_db
    when "arhp_test_db_b"
      Pool1DbA
    when "arhp_test_db_a"
      Pool1DbB
    else
      raise "Expected a database name, got #{first_db.inspect}"
    end
    expected_database = switch_to_klass.connection.instance_variable_get(:@database)

    # switch to the other database
    switch_to_klass.first
    puts "\nAnd now we're on #{current_database(switch_to_klass)}" if debug_me

    # get the current thread id so we can shoot ourselves in the head
    thread_id = switch_to_klass.connection.select_value("select @@pseudo_thread_id")

    # now, disable our auto-switching and trigger a mysql reconnect
    switch_to_klass.connection.unproxied.stub(:_switch_connection, true) do
      Pool2DbD.connection.execute("KILL #{thread_id}")
    end

    switch_to_klass.connection.reconnect!

    # and finally, did mysql reconnect correctly?
    puts "\nAnd now we end up on #{current_database(switch_to_klass)}" if debug_me
    assert_equal expected_database, current_database(switch_to_klass)
  end

  def test_release_connection
    pool = ActiveRecord::Base.connection_pool
    conn = pool.connection
    assert_called_with(pool, :checkin, [conn]) do
      pool.release_connection
    end
  end
end
