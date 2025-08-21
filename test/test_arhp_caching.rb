# frozen_string_literal: true

require_relative "helper"

class ActiveRecordHostCachingTest < Minitest::Test
  include ARHPTestSetup

  def teardown
    delete_all_records
    ActiveRecordHostPool::PoolProxy.class_variable_set(:@@_connection_pools, {})
  end

  def test_should_not_share_a_query_cache
    ActiveRecord::Base.clear_query_caches_for_current_thread

    Pool1DbA.create(val: "foo")
    Pool1DbB.create(val: "foobar")

    Pool1DbA.connection.cache do
      refute_equal Pool1DbA.first.val, Pool1DbB.first.val
    end
  end

  def test_models_with_matching_hosts_and_non_matching_databases_do_not_mix_up_underlying_database
    # ActiveRecord will clear the query cache after any action that dirties the cache (create, update, etc)
    # Because we're testing the patch we want to ensure it runs at least once
    ActiveRecord::Base.clear_query_caches_for_current_thread

    # ActiveRecord 6.0 introduced a change that surfaced a problematic code
    # path in active_record_host_pool when clearing caches across connection
    # handlers which can cause the database to change.
    # See ActiveRecordHostPool::ClearQueryCachePatch
    ActiveRecord::Base.cache { Pool1DbC.create! }
  end
end
