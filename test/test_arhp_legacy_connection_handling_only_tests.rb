# frozen_string_literal: true

require_relative 'helper'

if ENV['LEGACY_CONNECTION_HANDLING'] == 'true'
  class ActiveRecordHostPoolLegacyConnectiongHandlingTest < Minitest::Test
    include ARHPTestSetup
    def setup
      Phenix.rise!
      arhp_create_models
    end

    def teardown
      Phenix.burn!
    end

    def test_models_without_matching_replica_status_should_not_share_a_connection
      refute_equal(Pool1DbA.connection.raw_connection, Pool1DbAReplica.connection.raw_connection)
    end

    def test_models_with_matching_hosts_and_non_matching_databases_should_share_a_connection
      simulate_rails_app_active_record_railties
      assert_equal(Pool1DbA.connection.raw_connection, Pool1DbC.connection.raw_connection)
    end

    if ActiveRecord.version >= Gem::Version.new('6.0')
      def test_models_with_matching_hosts_and_non_matching_databases_issue_exists_without_arhp_patch
        simulate_rails_app_active_record_railties

        # Remove patch that fixes an issue in Rails 6+ to ensure it still
        # exists. If this begins to fail then it may mean that Rails has fixed
        # the issue so that it no longer occurs.
        without_module_patch(ActiveRecordHostPool::ClearQueryCachePatch, :clear_query_caches_for_current_thread) do
          without_module_patch(ActiveRecordHostPool::ClearQueryCachePatch, :clear_on_handler) do
            exception = assert_raises(ActiveRecord::StatementInvalid) do
              ActiveRecord::Base.cache { Pool1DbC.create! }
            end

            assert_equal("Mysql2::Error: Table 'arhp_test_db_b.pool1_db_cs' doesn't exist", exception.message)
          end
        end
      end

      def test_models_with_matching_hosts_and_non_matching_databases_do_not_mix_up_underlying_database
        simulate_rails_app_active_record_railties

        # ActiveRecord 6.0 introduced a change that surfaced a problematic code
        # path in active_record_host_pool when clearing caches across connection
        # handlers which can cause the database to change.
        # See ActiveRecordHostPool::ClearQueryCachePatch
        ActiveRecord::Base.cache { Pool1DbC.create! }
      end
    end

    private

    def simulate_rails_app_active_record_railties
      if ActiveRecord.version >= Gem::Version.new('6.0')
        # Necessary for testing ActiveRecord 6.0 which uses the connection
        # handlers when clearing query caches across all handlers when
        # an operation that dirties the cache is involved (e.g. create/insert,
        # update, delete/destroy, truncate, etc.)
        ActiveRecord::Base.connection_handlers = {
          ActiveRecord::Base.writing_role => ActiveRecord::Base.default_connection_handler
        }
      end
    end
  end
end
