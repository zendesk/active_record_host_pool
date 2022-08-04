# frozen_string_literal: true

if ActiveRecord.version >= Gem::Version.new('6.0')
  module ActiveRecordHostPool
    # ActiveRecord 6.0 introduced multiple database support. With that, an update
    # has been made in https://github.com/rails/rails/pull/35089 to ensure that
    # all query caches are cleared across connection handlers and pools. If you
    # write on one connection, the other connection will have the update that
    # occurred.
    #
    # This broke ARHP which implements its own pool, allowing you to access
    # multiple databases with the same connection (e.g. 1 connection for 100
    # shards on the same server).
    #
    # This patch maintains the reference to the database during the cache clearing
    # to ensure that the database doesn't get swapped out mid-way into an
    # operation.
    #
    # This is a private Rails API and may change in future releases as they're
    # actively working on sharding in Rails 6 and above.
    module ClearQueryCachePatch
      def clear_query_caches_for_current_thread
        host_pool_current_database_was = connection.unproxied._host_pool_current_database
        # p "DB was: #{host_pool_current_database_was}"
        super
      # rescue ActiveRecord::StatementInvalid
      ensure
        # restore in case clearing the cache changed the database
        # p "DB is now #{connection.unproxied._host_pool_current_database}"
        connection.unproxied._host_pool_current_database = host_pool_current_database_was
      end

      if ActiveRecord.version >= Gem::Version.new('6.1') && !ActiveRecord::Base.legacy_connection_handling
        def clear_on_handler(handler)
          handler.all_connection_pools.each do |pool|
            db_was = pool.connection.unproxied._host_pool_current_database
            pool.connection.clear_query_cache if pool.active_connection?
            pool.connection.unproxied._host_pool_current_database = db_was
          end
        end
      end
    end
  end

  ActiveRecord::Base.singleton_class.prepend ActiveRecordHostPool::ClearQueryCachePatch
end
