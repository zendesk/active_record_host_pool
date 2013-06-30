['mysql_adapter', 'mysql2_adapter'].each do |adapter|
  begin
    require "active_record/connection_adapters/#{adapter}"
  rescue LoadError
  end
end

module ActiveRecordHostPool
  module DatabaseSwitch
    def self.included(base)
      base.class_eval do
        attr_accessor(:_host_pool_current_database)
        alias_method_chain :execute, :switching
        alias_method_chain :exec_stmt, :switching if private_instance_methods.map(&:to_sym).include?(:exec_stmt)
        alias_method_chain :drop_database, :no_switching
        alias_method_chain :create_database, :no_switching
        alias_method_chain :disconnect!, :host_pooling
      end
    end

    def execute_with_switching(*args)
      if _host_pool_current_database && ! @_no_switch
        _switch_connection
      end
      execute_without_switching(*args)
    end

    def exec_stmt_with_switching(sql, name, binds, &block)
      if _host_pool_current_database && ! @_no_switch
        _switch_connection
      end
      exec_stmt_without_switching(sql, name, binds, &block)
    end

    def drop_database_with_no_switching(*args)
      begin
        @_no_switch = true
        drop_database_without_no_switching(*args)
      ensure
        @_no_switch = false
      end
    end

    def create_database_with_no_switching(*args)
      begin
        @_no_switch = true
        create_database_without_no_switching(*args)
      ensure
        @_no_switch = false
      end
    end

    def disconnect_with_host_pooling!
      @_cached_current_database = nil
      disconnect_without_host_pooling!
    end

    private

    def _switch_connection
      if _host_pool_current_database && ((_host_pool_current_database != @_cached_current_database) || @connection.object_id != @_cached_connection_object_id)
        log("select_db #{_host_pool_current_database}", "SQL") do
          clear_cache! if respond_to?(:clear_cache!)
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
end

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandler
      def establish_connection(name, spec)
        if @class_to_pool # AR 3.2
          @connection_pools[spec] ||= ActiveRecordHostPool::PoolProxy.new(spec)
          @class_to_pool[name] = @connection_pools[spec]
        else # AR 3.1 and lower
          @connection_pools[name] = ActiveRecordHostPool::PoolProxy.new(spec)
        end
      end
    end
  end
end

["MysqlAdapter", "Mysql2Adapter"].each do |k|
  next unless ActiveRecord::ConnectionAdapters.const_defined?(k)
  ActiveRecord::ConnectionAdapters.const_get(k).class_eval { include ActiveRecordHostPool::DatabaseSwitch }
end
