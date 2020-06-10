# frozen_string_literal: true

require "active_record/connection_adapters/mysql2_adapter"

module ActiveRecordHostPool
  module DatabaseSwitch
    def self.included(base)
      base.class_eval do
        alias_method :execute_without_switching, :execute
        alias_method :execute, :execute_with_switching

        alias_method :drop_database_without_no_switching, :drop_database
        alias_method :drop_database, :drop_database_with_no_switching

        alias_method :create_database_without_no_switching, :create_database
        alias_method :create_database, :create_database_with_no_switching

        alias_method :disconnect_without_host_pooling!, :disconnect!
        alias_method :disconnect!, :disconnect_with_host_pooling!
      end
    end

    def execute_with_switching(*args)
      if _host_pool_current_database && !_no_switch
        _switch_connection
      end
      execute_without_switching(*args)
    end

    def drop_database_with_no_switching(*args)
      self._no_switch = true
      drop_database_without_no_switching(*args)
    ensure
      self._no_switch = false
    end

    def create_database_with_no_switching(*args)
      self._no_switch = true
      create_database_without_no_switching(*args)
    ensure
      self._no_switch = false
    end

    def disconnect_with_host_pooling!
      self._cached_connection_object_id = nil
      disconnect_without_host_pooling!
    end

    def _host_pool_current_database
      _ahrp_storage[:_host_pool_current_database]
    end

    def _host_pool_current_database=(database)
      _ahrp_storage[:_host_pool_current_database] = database
      @config[:database] = _host_pool_current_database
    end

    private

    attr_accessor :_cached_connection_object_id, :_cached_current_database, :_no_switch

    def _ahrp_storage
      @_ahrp_storage ||= {}
    end

    def _ahrp_fetch_database_to_switch_to
      database_name = _host_pool_current_database
      if database_name != _cached_current_database || connection.object_id != _cached_connection_object_id
        database_name
      end
    end

    def _switch_connection
      database_name = _ahrp_fetch_database_to_switch_to
      if database_name
        log("select_db #{database_name}", "SQL") do
          clear_cache! if respond_to?(:clear_cache!)
          raw_connection.select_db(database_name)
        end
        self._cached_connection_object_id = @connection.object_id
      end
    end

    # prevent different databases from sharing the same query cache
    def cache_sql(sql, *args)
      super(_host_pool_current_database.to_s + "/" + sql, *args)
    end
  end

  module PerThreadHashAccess
    # PerThreadHashAccess.module_for(...) returns a module which scopes hash accessor methods
    # to the given connection_id with thread-local values. It uses `super` as a fallback. This is to
    # make access to the config object on a ActiveRecord::ConnectionAdapters::Mysql2Adapter
    # thread-safe.
    #
    # Because AHRP shares the connection across members of its connection pool it is possible for
    # multiple threads be simultaneously trying to talk to the database.
    def self.module_for(connection_id)
      Module.new do
        define_method(:[]=) do |key, value|
          _ahrp_storage[key] = value
        end

        define_method(:[]) do |key|
          if _ahrp_storage.key?(key)
            _ahrp_storage[key]
          else
            _ahrp_storage[key] = super(key)
          end
        end

        define_method(:fetch) do |*args, &blk|
          key, = args
          _ahrp_storage.fetch(key) do
            _ahrp_storage[key] = super(*args, &blk)
          end
        end

        private

        define_method(:_ahrp_storage) do
          ThreadSafe.storage[connection_id]
        end
      end
    end
  end

  module ThreadSafe
    def self.storage
      Thread.current[:active_record_host_pool] ||= Hash.new { |hash, key| hash[key] = {} }
    end

    def initialize(*)
      super

      @config.singleton_class.prepend PerThreadHashAccess.module_for(@connection.object_id)
    end

    private

    def _ahrp_storage
      ThreadSafe.storage[_cached_connection_object_id]
    end

    def _ahrp_fetch_database_to_switch_to
      _host_pool_current_database
    end
  end
end

# rubocop:disable Lint/DuplicateMethods
module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandler
      case "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"
      when '5.1', '5.2', '6.0'

        def establish_connection(spec)
          resolver = ConnectionAdapters::ConnectionSpecification::Resolver.new(Base.configurations)
          spec = resolver.spec(spec)

          owner_to_pool[spec.name] = ActiveRecordHostPool::PoolProxy.new(spec)
        end

      when '4.2'

        def establish_connection(owner, spec)
          @class_to_pool.clear
          raise "Anonymous class is not allowed." unless owner.name

          owner_to_pool[owner.name] = ActiveRecordHostPool::PoolProxy.new(spec)
        end

      else

        raise "Unsupported version of Rails (v#{ActiveRecord::VERSION::STRING})"
      end
    end
  end
end
# rubocop:enable Lint/DuplicateMethods

ActiveRecord::ConnectionAdapters::Mysql2Adapter.include(ActiveRecordHostPool::DatabaseSwitch)
ActiveRecord::ConnectionAdapters::Mysql2Adapter.include(ActiveRecordHostPool::ThreadSafe)
