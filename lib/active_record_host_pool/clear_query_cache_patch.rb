# frozen_string_literal: true

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
module ActiveRecordHostPool
  # For Rails 7.1+
  module ClearQueryCachePatch
    def clear_query_caches_for_current_thread
      connection_handler.each_connection_pool do |pool|
        pool._unproxied_connection.clear_query_cache if pool.active_connection?
      end
    end
  end

  # For Rails 6.1 & 7.0.
  module ClearOnHandlerPatch
    def clear_on_handler(handler)
      handler.all_connection_pools.each do |pool|
        pool._unproxied_connection.clear_query_cache if pool.active_connection?
      end
    end
  end
end

case "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"
when "6.1", "7.0"
  ActiveRecord::Base.singleton_class.prepend(ActiveRecordHostPool::ClearOnHandlerPatch)
else
  # Fix https://github.com/rails/rails/commit/401e2f24161ed6047ae33c322aaf6584b7728ab9
  ActiveRecord::Base.singleton_class.prepend(ActiveRecordHostPool::ClearQueryCachePatch)
end
