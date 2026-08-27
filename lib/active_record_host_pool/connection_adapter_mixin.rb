# frozen_string_literal: true

begin
  require "active_record/connection_adapters/mysql2_adapter"
rescue LoadError
  :noop
end

begin
  require "active_record/connection_adapters/trilogy_adapter"
rescue LoadError
  :noop
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

    def with_raw_connection(...)
      super do |real_connection|
        _switch_connection(real_connection) if _host_pool_desired_database && !_no_switch
        yield real_connection
      end
    end

    # Rails 8.2 executes queries via QueryIntent -> execute_intent -> perform_query,
    # bypassing with_raw_connection, so the switch must happen here instead. Raising
    # from here (e.g. a lost connection during select_db) feeds into the intent's
    # retry/reconnect machinery, matching the old with_raw_connection semantics.
    if ActiveRecord.version >= Gem::Version.new("8.2.a")
      def perform_query(raw_connection, intent)
        _switch_connection(raw_connection) if _host_pool_desired_database && !_no_switch
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

    def _switch_connection(real_connection)
      if _host_pool_desired_database &&
          (
            _desired_database_changed? ||
             _real_connection_changed?
          )
        _log_select_db do
          clear_cache!
          real_connection.select_db(_host_pool_desired_database)
        end
        @_cached_current_database = _host_pool_desired_database
        @_cached_connection_object_id = _real_connection_object_id
      end
    end

    if ActiveRecord.version >= Gem::Version.new("8.1")
      def _log_select_db(&block)
        instrumenter.instrument(
          "sql.active_record",
          sql: "select_db #{_host_pool_desired_database}",
          name: "SQL",
          binds: [],
          type_casted_binds: [],
          async: false,
          allow_retry: false,
          connection: self,
          transaction: current_transaction.user_transaction.presence,
          affected_rows: 0,
          row_count: 0,
          &block
        )
      end
    else
      def _log_select_db(&block)
        log("select_db #{_host_pool_desired_database}", "SQL", &block)
      end
    end

    def _desired_database_changed?
      _host_pool_desired_database != @_cached_current_database
    end

    def _real_connection_object_id
      @raw_connection.object_id
    end

    def _real_connection_changed?
      _real_connection_object_id != @_cached_connection_object_id
    end

    # prevent different databases from sharing the same query cache
    def cache_sql(sql, *args)
      super(_host_pool_desired_database.to_s + "/" + sql, *args)
    end
  end

  module PoolConfigPatch
    def pool
      @pool || synchronize { @pool ||= ActiveRecordHostPool::PoolProxy.new(self) }
    end
  end
end

ActiveRecord::ConnectionAdapters::Mysql2Adapter.prepend(ActiveRecordHostPool::DatabaseSwitch) if defined?(ActiveRecord::ConnectionAdapters::Mysql2Adapter)
ActiveRecord::ConnectionAdapters::TrilogyAdapter.prepend(ActiveRecordHostPool::DatabaseSwitch) if defined?(ActiveRecord::ConnectionAdapters::TrilogyAdapter)
ActiveRecord::ConnectionAdapters::PoolConfig.prepend(ActiveRecordHostPool::PoolConfigPatch)
