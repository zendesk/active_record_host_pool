# frozen_string_literal: true

require 'delegate'
require 'active_record'
require 'active_record_host_pool/connection_adapter_mixin'

# this module sits in between ConnectionHandler and a bunch of different ConnectionPools (one per host).
# when a connection is requested, it goes like:
# ActiveRecordClass -> ConnectionHandler#connection
# ConnectionHandler#connection -> (find or create PoolProxy)
# PoolProxy -> shared list of Pools
# Pool actually gives back a connection, then PoolProxy turns this
# into a ConnectionProxy that can inform (on execute) which db we should be on.

module ActiveRecordHostPool
  # Sits between ConnectionHandler and a bunch of different ConnectionPools (one per host).
  class PoolProxy < Delegator
    def initialize(pool_config)
      super(pool_config)
      @pool_config = pool_config
      @config = pool_config.db_config.configuration_hash
    end

    def __getobj__
      _connection_pool
    end

    def __setobj__(pool_config)
      @pool_config = pool_config
      @config = pool_config.db_config.configuration_hash
      @_pool_key = nil
    end

    attr_reader :pool_config

    def connection(*args)
      real_connection = _unproxied_connection(*args)
      _connection_proxy_for(real_connection, @config[:database])
    rescue Mysql2::Error, ActiveRecord::NoDatabaseError
      _connection_pools.delete(_pool_key)
      Kernel.raise
    end

    def _unproxied_connection(*args)
      _connection_pool.connection(*args)
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
      p = _connection_pool(false)
      return unless p

      p.disconnect!
      p.automatic_reconnect = true
      _clear_connection_proxy_cache
    end

    def automatic_reconnect=(value)
      p = _connection_pool(false)
      return unless p

      p.automatic_reconnect = value
    end

    def clear_reloadable_connections!
      _connection_pool.clear_reloadable_connections!
      _clear_connection_proxy_cache
    end

    def release_connection(*args)
      p = _connection_pool(false)
      return unless p

      p.release_connection(*args)
    end

    def flush!
      p = _connection_pool(false)
      return unless p

      p.flush!
    end

    def discard!
      p = _connection_pool(false)
      return unless p

      p.discard!

      # All connections in the pool (even if they're currently
      # leased!) have just been discarded, along with the pool itself.
      # Any further interaction with the pool (except #pool_config and #schema_cache)
      # is undefined.
      # Remove the connection for the given key so a new one can be created in its place
      _connection_pools.delete(_pool_key)
    end

    private

    def _connection_pools
      @@_connection_pools ||= {}
    end

    def _pool_key
      @_pool_key ||= "#{@config[:host]}/#{@config[:port]}/#{@config[:socket]}/" \
                     "#{@config[:username]}/#{replica_configuration? && 'replica'}"
    end

    def _connection_pool(auto_create = true)
      pool = _connection_pools[_pool_key]
      if pool.nil? && auto_create
        pool = _connection_pools[_pool_key] = ActiveRecord::ConnectionAdapters::ConnectionPool.new(@pool_config)
      end
      pool
    end

    def _connection_proxy_for(connection, database)
      @connection_proxy_cache ||= {}
      key = [connection, database]

      @connection_proxy_cache[key] ||= begin
        cx = ActiveRecordHostPool::ConnectionProxy.new(connection, database)
        cx.execute('select 1')
        cx
      end
    end

    def _clear_connection_proxy_cache
      @connection_proxy_cache = {}
    end

    def replica_configuration?
      @config[:replica] || @config[:slave]
    end
  end
end
