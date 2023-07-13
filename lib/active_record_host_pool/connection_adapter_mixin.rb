# frozen_string_literal: true

case ActiveRecordHostPool.loaded_db_adapter
when :mysql2
  require "active_record/connection_adapters/mysql2_adapter"
when :trilogy
  require "trilogy_adapter/connection"
  require "trilogy_adapter/errors"
  ActiveRecord::Base.extend TrilogyAdapter::Connection
end

module ActiveRecordHostPool
  module DatabaseSwitch
    def self.included(base)
      base.class_eval do
        attr_reader(:_host_pool_current_database)

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

    def initialize(*)
      @_cached_current_database = nil
      super
    end

    def _host_pool_current_database=(database)
      @_host_pool_current_database = database
      @config[:database] = _host_pool_current_database
    end

    def self.ruby2_keywords(*); end unless respond_to?(:ruby2_keywords, true)
    # This one really does need ruby2_keywords; in Rails 6.0 the method does not take
    # any keyword arguments, but in Rails 7.0 it does. So, we don't know whether or not
    # what we're delegating to takes kwargs, so ruby2_keywords is needed.
    ruby2_keywords def execute_with_switching(*args)
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
