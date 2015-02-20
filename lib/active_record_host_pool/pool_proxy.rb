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
      @_pool_key = nil
    end

    def spec
      @spec
    end

    def connection(*args)
      begin
        real_connection = _connection_pool.connection(*args)
        _connection_proxy_for(real_connection, @config[:database])
      rescue Exception => e
        if rescuable_errors.any? { |r| e.is_a?(r) }
          _connection_pools.delete(_pool_key)
        end
        Kernel.raise(e)
      end
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
      _connection_pool.disconnect!
      _connection_pool.automatic_reconnect = true if _connection_pool.respond_to?(:automatic_reconnect=)
      _clear_connection_proxy_cache
    end

    def clear_reloadable_connections!
      _connection_pool.clear_reloadable_connections!
      _clear_connection_proxy_cache
    end

  private
    def rescuable_errors
      @rescuable_errors ||= begin
        e = []
        if Object.const_defined?("Mysql")
          e << Mysql::Error
        end
        if Object.const_defined?("Mysql2")
          e << Mysql2::Error
        end
        if ActiveRecord.const_defined?("NoDatabaseError")
          e << ActiveRecord::NoDatabaseError
        end
        e
      end
    end

    def _connection_pools
      @@_connection_pools ||= {}
    end

    def _pool_key
      @_pool_key ||= "#{@config[:host]}/#{@config[:port]}/#{@config[:socket]}/#{@config[:username]}"
    end

    def _connection_pool(auto_create=true)
      pool = _connection_pools[_pool_key]
      if pool.nil? && auto_create
        pool = _connection_pools[_pool_key] = ActiveRecord::ConnectionAdapters::ConnectionPool.new(@spec)
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
  end
end

