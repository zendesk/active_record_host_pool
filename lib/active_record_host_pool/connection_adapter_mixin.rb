# frozen_string_literal: true

case ActiveRecordHostPool.loaded_db_adapter
when :mysql2
  require "active_record/connection_adapters/mysql2_adapter"
when :trilogy
  case "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"
  when "6.1", "7.0"
    require "trilogy_adapter/connection"
    ActiveRecord::Base.extend(TrilogyAdapter::Connection)
  when "7.1"
    require "active_record/connection_adapters/trilogy_adapter"
  else
    raise "Unsupported version of Rails (v#{ActiveRecord::VERSION::STRING})"
  end
end

module ActiveRecordHostPool
  module DatabaseSwitch
    attr_reader :_host_pool_desired_database
    def initialize(*)
      @_cached_current_database = nil
      super
    end

    def _host_pool_desired_database=(database)
      @_host_pool_desired_database = database
      @config[:database] = _host_pool_desired_database
    end

    if ActiveRecord.version >= Gem::Version.new("7.1") || ActiveRecordHostPool.loaded_db_adapter == :trilogy
      # Patch `raw_execute` instead of `execute` since this commit:
      # https://github.com/rails/rails/commit/f69bbcbc0752ca5d5af327d55922614a26f5c7e9
      def raw_execute(...)
        if _host_pool_desired_database && !_no_switch
          _switch_connection
        end
        super
      end
    else
      def execute(...)
        if _host_pool_desired_database && !_no_switch
          _switch_connection
        end
        super
      end
    end

    def drop_database(...)
      self._no_switch = true
      super
    ensure
      self._no_switch = false
    end

    def create_database(...)
      self._no_switch = true
      super
    ensure
      self._no_switch = false
    end

    def disconnect!
      @_cached_current_database = nil
      @_cached_connection_object_id = nil
      super
    end

    private

    attr_accessor :_no_switch

    def _switch_connection
      if _host_pool_desired_database &&
          (
            (_host_pool_desired_database != @_cached_current_database) ||
            @connection.object_id != @_cached_connection_object_id
          )
        log("select_db #{_host_pool_desired_database}", "SQL") do
          clear_cache!
          raw_connection.select_db(_host_pool_desired_database)
        end
        @_cached_current_database = _host_pool_desired_database
        @_cached_connection_object_id = @connection.object_id
      end
    end

    # prevent different databases from sharing the same query cache
    def cache_sql(sql, *args)
      super(_host_pool_desired_database.to_s + "/" + sql, *args)
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
  ActiveRecord::ConnectionAdapters::Mysql2Adapter.prepend(ActiveRecordHostPool::DatabaseSwitch)
when :trilogy
  ActiveRecord::ConnectionAdapters::TrilogyAdapter.prepend(ActiveRecordHostPool::DatabaseSwitch)
end

ActiveRecord::ConnectionAdapters::PoolConfig.prepend(ActiveRecordHostPool::PoolConfigPatch)
