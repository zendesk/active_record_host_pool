require File.expand_path('helper', File.dirname(__FILE__))

class ActiveRecordHostPoolTest < Test::Unit::TestCase
  include ARHPTestSetup
  def setup
    arhp_create_databases
    arhp_create_models
  end

  def test_models_with_matching_hosts_should_share_a_connection
    assert(Test1.connection.raw_connection == Test2.connection.raw_connection)
    assert(Test3.connection.raw_connection == Test4.connection.raw_connection)
  end

  def test_models_without_matching_hosts_should_not_share_a_connection
    assert(Test1.connection.raw_connection != Test4.connection.raw_connection)
  end

  def test_models_without_matching_usernames_should_not_share_a_connection
    assert(Test4.connection.raw_connection != Test5.connection.raw_connection)
  end

  def test_should_select_on_correct_database
    action_should_use_correct_database(:select_all, "select 1")
  end

  def test_should_insert_on_correct_database
    action_should_use_correct_database(:insert, "insert into tests values(NULL, 'foo')")
  end

  def test_connection_returns_a_proxy
    assert Test1.connection.is_a?(ActiveRecordHostPool::ConnectionProxy)
  end

  def test_should_not_share_a_query_cache
    Test1.create(:val => 'foo')
    Test2.create(:val => 'foobar')
    Test1.connection.cache do
      assert Test1.first.val != Test2.first.val
    end
  end

  def test_object_creation
    Test1.create(:val => 'foo')
    assert_equal("arhp_test_1", current_database(Test1))

    Test3.create(:val => 'bar')
    assert_equal("arhp_test_1", current_database(Test1))
    assert_equal("arhp_test_3", current_database(Test3))

    Test2.create!(:val => 'bar_distinct')
    assert_equal("arhp_test_2", current_database(Test2))
    assert Test2.find_by_val('bar_distinct')
    assert !Test1.find_by_val('bar_distinct')
  end

  def test_disconnect
    Test1.create(:val => 'foo')
    unproxied = Test1.connection.unproxied
    Test1.connection_handler.clear_all_connections!
    Test1.create(:val => 'foo')
    assert(unproxied != Test1.connection.unproxied)
  end

  def test_checkout
    connection = ActiveRecord::Base.connection_pool.checkout
    assert(connection.is_a?(ActiveRecordHostPool::ConnectionProxy))
    ActiveRecord::Base.connection_pool.checkin(connection)
    c2 = ActiveRecord::Base.connection_pool.checkout
    assert(c2 == connection)
  end


  def test_underlying_assumption_about_test_db
    debug_me = false
    # ensure connection
    Test1.first

    # which is the "default" DB to connect to?
    first_db = Test1.connection.unproxied.instance_variable_get("@connection_options")[3]
    puts "\nOk, we started on #{first_db}" if debug_me

    switch_to_klass = case first_db
      when "arhp_test_2"
        Test1
      when "arhp_test_1"
        Test2
    end
    expected_database = switch_to_klass.connection.instance_variable_get("@database")

    # switch to the other database
    switch_to_klass.first
    puts "\nAnd now we're on #{current_database(switch_to_klass)}" if debug_me

    # get the current thread id so we can shoot ourselves in the head
    thread_id = switch_to_klass.connection.select_value("select @@pseudo_thread_id")

    # now, disable our auto-switching and trigger a mysql reconnect
    switch_to_klass.connection.unproxied.stubs(:_switch_connection).returns(true)
    Test3.connection.execute("KILL #{thread_id}")

    # and finally, did mysql reconnect correctly?
    puts "\nAnd now we end up on #{current_database(switch_to_klass)}" if debug_me
    assert_equal expected_database, current_database(switch_to_klass)
  end

  # rake db:create uses a pattern where it tries to connect to a non-existant database.
  # but then we had this left in the connection pool cache.
  # It's also almost impossible to test at this level, so I'm stubbing out the test
  def _test_connecting_to_wrong_db_first
    pools = ActiveRecord::Base.connection_handler.connection_pools
    if !pools.empty?
      ActiveRecord::Base.connection_handler.connection_pools.values.first.send(:_connection_pools).clear
      ActiveRecord::Base.connection_handler.connection_pools.clear
    end

    begin
      eval <<-EOC
        class TestNotThere < ActiveRecord::Base
          establish_connection("test_host_1_db_not_there")
        end
      EOC
    rescue Exception => e
      assert e.message =~ /Unknown database/
    end

    Test1.establish_connection("test_host_1_db_1")
    # assert it doesn't raise.
    assert Test1.connection
  end

  def teardown
    arhp_drop_databases
  end

  private

  def action_should_use_correct_database(action, sql)
    (1..4).each { |i|
      klass = eval "Test#{i}"
      desired_db = "arhp_test_#{i}"
      klass.connection.send(action, sql)
      assert_equal desired_db, current_database(klass)
    }
  end
end
