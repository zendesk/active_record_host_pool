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

    def connection(*args)
      cx = _connection_pool.connection(*args)
      if !cx.respond_to?(:_host_pool_current_database)
        cx.class.class_eval { include ActiveRecordHostPool::DatabaseSwitch }
      end
      # we could in theory keep a cache here to prevent so much object creation.
      # should do a speed test to see if this matters.
      ActiveRecordHostPool::ConnectionProxy.new(cx, @config[:database])
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
  end
end
