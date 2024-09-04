# frozen_string_literal: true

require "delegate"
require "active_record"
require "active_record_host_pool/connection_adapter_mixin"
require "mutex_m"

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
    include Mutex_m

    case ActiveRecordHostPool.loaded_db_adapter
    when :mysql2
      RESCUABLE_DB_ERROR = Mysql2::Error
    when :trilogy
      RESCUABLE_DB_ERROR = Trilogy::ProtocolError
    end

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

    # rubocop:disable Lint/DuplicateMethods
    case "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"
    when "6.1", "7.0", "7.1"
      def connection(*args)
        real_connection = _unproxied_connection(*args)
        _connection_proxy_for(real_connection, @config[:database])
      rescue RESCUABLE_DB_ERROR, ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
        _connection_pools.delete(_pool_key)
        Kernel.raise
      end

      def _unproxied_connection(*args)
        _connection_pool.connection(*args)
      end
    else
      def lease_connection(*args)
        real_connection = _unproxied_connection(*args)
        _connection_proxy_for(real_connection, @config[:database])
      rescue RESCUABLE_DB_ERROR, ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
        _connection_pools.delete(_pool_key)
        Kernel.raise
      end
      alias_method :connection, :lease_connection

      def _unproxied_connection(*args)
        _connection_pool.lease_connection(*args)
      end
    end
    # rubocop:enable Lint/DuplicateMethods

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

    case "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"
    when "6.1", "7.0", "7.1"
      def with_connection
        cx = checkout
        yield cx
      ensure
        checkin cx
      end
    else
      def with_connection(prevent_permanent_checkout: false) # rubocop:disable Lint/DuplicateMethods
        real_connection_lease = _connection_pool.send(:connection_lease)
        sticky_was = real_connection_lease.sticky
        real_connection_lease.sticky = false if prevent_permanent_checkout

        if real_connection_lease.connection
          begin
            yield _connection_proxy_for(real_connection_lease.connection, @config[:database])
          ensure
            real_connection_lease.sticky = sticky_was if prevent_permanent_checkout && !sticky_was
          end
        else
          begin
            real_connection_lease.connection = _unproxied_connection
            yield _connection_proxy_for(real_connection_lease.connection, @config[:database])
          ensure
            real_connection_lease.sticky = sticky_was if prevent_permanent_checkout && !sticky_was
            _connection_pool.release_connection(real_connection_lease) unless real_connection_lease.sticky
          end
        end
      end

      def active_connection?
        real_connection_lease = _connection_pool.send(:connection_lease)
        if real_connection_lease.connection
          _connection_proxy_for(real_connection_lease.connection, @config[:database])
        end
      end
      alias_method :active_connection, :active_connection?

      def schema_cache
        @schema_cache ||= ActiveRecord::ConnectionAdapters::BoundSchemaReflection.new(_connection_pool.schema_reflection, self)
      end
    end

    def disconnect!
      p = _connection_pool(false)
      return unless p

      synchronize do
        p.disconnect!
        p.automatic_reconnect = true
        _clear_connection_proxy_cache
      end
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
                     "#{@config[:username]}/#{replica_configuration? && "replica"}"
    end

    def _connection_pool(auto_create = true)
      pool = _connection_pools[_pool_key]
      if pool.nil? && auto_create
        pool = _connection_pools[_pool_key] = ActiveRecord::ConnectionAdapters::ConnectionPool.new(@pool_config)
      end
      pool
    end

    # Work around https://github.com/rails/rails/pull/48061/commits/63c0d6b31bcd0fc33745ec6fd278b2d1aab9be54
    # standard:disable Lint/DuplicateMethods
    case "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"
    when "6.1", "7.0"
      def _connection_proxy_for(connection, database)
        @connection_proxy_cache ||= {}
        key = [connection, database]

        @connection_proxy_cache[key] ||= begin
          cx = ActiveRecordHostPool::ConnectionProxy.new(connection, database)
          cx.execute("SELECT 1")

          cx
        end
      end
    else
      def _connection_proxy_for(connection, database)
        @connection_proxy_cache ||= {}
        key = [connection, database]

        @connection_proxy_cache[key] ||= ActiveRecordHostPool::ConnectionProxy.new(connection, database)
      end
    end
    # standard:enable Lint/DuplicateMethods

    def _clear_connection_proxy_cache
      @connection_proxy_cache = {}
    end

    def replica_configuration?
      @config[:replica] || @config[:slave]
    end
  end
end
