# frozen_string_literal: true

case ActiveRecordHostPool.loaded_db_adapter
when :mysql2
  require "active_record/connection_adapters/mysql2_adapter"
when :trilogy
  case "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"
  when "6.1", "7.0"
    require "trilogy_adapter/connection"
    require "trilogy_adapter/errors"
    ActiveRecord::Base.extend(TrilogyAdapter::Connection)
  when "7.1"
    require "active_record/connection_adapters/trilogy_adapter"
  else
    raise "Unsupported version of Rails (v#{ActiveRecord::VERSION::STRING})"
  end
end

module ActiveRecordHostPool
  module DatabaseSwitch
    def self.included(base)
      base.class_eval do
        attr_reader(:_host_pool_current_database)

        # Patch `raw_execute` instead of `execute` since this commit:
        # https://github.com/rails/rails/commit/f69bbcbc0752ca5d5af327d55922614a26f5c7e9
        case "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"
        when "7.1"
          alias_method :raw_execute_without_switching, :raw_execute
          alias_method :raw_execute, :raw_execute_with_switching
        else
          alias_method :execute_without_switching, :execute
          alias_method :execute, :execute_with_switching
        end

        alias_method :drop_database_without_no_switching, :drop_database
        alias_method :drop_database, :drop_database_with_no_switching

        alias_method :create_database_without_no_switching, :create_database
        alias_method :create_database, :create_database_with_no_switching

        alias_method :disconnect_without_host_pooling!, :disconnect!
        alias_method :disconnect!, :disconnect_with_host_pooling!
      end
    end

    def initialize(*)
      @_cached_current_database = nil
      super
    end

    def _host_pool_current_database=(database)
      @_host_pool_current_database = database
      @config[:database] = _host_pool_current_database
    end

    if ActiveRecord.version >= Gem::Version.new("7.1")
      def raw_execute_with_switching(...)
        if _host_pool_current_database && !_no_switch
          _switch_connection
        end
        raw_execute_without_switching(...)
      end
    else
      def execute_with_switching(...)
        if _host_pool_current_database && !_no_switch
          _switch_connection
        end
        execute_without_switching(...)
      end
    end

    def drop_database_with_no_switching(...)
      self._no_switch = true
      drop_database_without_no_switching(...)
    ensure
      self._no_switch = false
    end

    def create_database_with_no_switching(...)
      self._no_switch = true
      create_database_without_no_switching(...)
    ensure
      self._no_switch = false
    end

    def disconnect_with_host_pooling!
      @_cached_current_database = nil
      @_cached_connection_object_id = nil
      disconnect_without_host_pooling!
    end

    private

    attr_accessor :_no_switch

    def _switch_connection
      if _host_pool_current_database &&
          (
            (_host_pool_current_database != @_cached_current_database) ||
            @connection.object_id != @_cached_connection_object_id
          )
        log("select_db #{_host_pool_current_database}", "SQL") do
          clear_cache!
          raw_connection.select_db(_host_pool_current_database)
        end
        @_cached_current_database = _host_pool_current_database
        @_cached_connection_object_id = @connection.object_id
      end
    end

    # prevent different databases from sharing the same query cache
    def cache_sql(sql, *args)
      super(_host_pool_current_database.to_s + "/" + sql, *args)
    end
  end

  module PoolConfigPatch
    def pool
      ActiveSupport::ForkTracker.check!

      @pool || synchronize { @pool ||= ActiveRecordHostPool::PoolProxy.new(self) }
    end
  end
end

case ActiveRecordHostPool.loaded_db_adapter
when :mysql2
  ActiveRecord::ConnectionAdapters::Mysql2Adapter.include(ActiveRecordHostPool::DatabaseSwitch)
when :trilogy
  ActiveRecord::ConnectionAdapters::TrilogyAdapter.include(ActiveRecordHostPool::DatabaseSwitch)
end

ActiveRecord::ConnectionAdapters::PoolConfig.prepend(ActiveRecordHostPool::PoolConfigPatch)
