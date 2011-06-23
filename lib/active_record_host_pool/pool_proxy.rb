require 'delegate'

# this module sits in between ConnectionHandler and a bunch of different ConnectionPools (one per host).
# when a connection is requested, it goes like:
# ActiveRecordClass -> ConnectionHandler#connection
# ConnectionHandler#connection -> (find or create PoolProxy)
# PoolProxy -> shared list of Pools
# Pool actually gives back a connection, then PoolProxy turns this
# into a ConnectionProxy that can inform (on execute) which db we should be on.

module ActiveRecordHostPool
  class PoolProxy < Delegator
    def initialize(spec)
      super(spec)
      @spec = spec
      @config = spec.config.with_indifferent_access
    end

    def __getobj__
      _connection_pool
    end

    def __setobj__(spec)
      @spec = spec
      @config = spec.config.with_indifferent_access
    end


    def connection(*args)
      cx = _connection_pool.connection(*args)
      _connection_proxy_for(cx, @config[:database])
    end

    # by the time we are patched into ActiveRecord, the current thread has already established
    # a connection.  thus we need to patch both connection and checkout/checkin
    def checkout(*args, &block)
      cx = _connection_pool.checkout(*args, &block)
      _connection_proxy_for(cx, @config[:database])
    end

    def checkin(cx)
      cx = cx.unproxied
      _connection_pool.checkin(cx)
    end

    def with_connection
      cx = checkout
        yield cx
      ensure
        checkin cx
    end

    def disconnect!
      _clear_connection_proxy_cache
      _connection_pool.disconnect!
    end

    def clear_reloadable_connections!
      _clear_connection_proxy_cache
      _connection_pool.clear_reloadable_connections!
    end

  private
    def _connection_pools
      @@connection_pools ||= {}
    end

    def _pool_key
      [@config[:host], @config[:port], @config[:socket]]
    end

    def _connection_pool
      pool = _connection_pools[_pool_key]
      if pool.nil?
        pool = _connection_pools[_pool_key] = ActiveRecord::ConnectionAdapters::ConnectionPool.new(@spec)
      end
      pool
    end

    def _connection_proxy_for(connection, database)
      @connection_proxy_cache ||= {}
      if !connection.respond_to?(:_host_pool_current_database)
        connection.class.class_eval { include ActiveRecordHostPool::DatabaseSwitch }
      end
      key = [connection, database]

      proxy = @connection_proxy_cache[key]
      if !proxy
        proxy = @connection_proxy_cache[key] = ActiveRecordHostPool::ConnectionProxy.new(connection, database)
      end
      proxy
    end

    def _clear_connection_proxy_cache
      @connection_proxy_cache = {}
    end
  end
end
