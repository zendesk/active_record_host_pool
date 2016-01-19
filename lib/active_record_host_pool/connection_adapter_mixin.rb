['mysql_adapter', 'mysql2_adapter'].each do |adapter|
  begin
    require "active_record/connection_adapters/#{adapter}"
  rescue LoadError
  end
end

module ActiveRecordHostPool
  module DatabaseSwitch
    def self.prepended(base)
      base.class_eval do
        attr_accessor(:_host_pool_current_database)
      end
    end

    def execute(*args)
      if _host_pool_current_database && ! @_no_switch
        _switch_connection
      end
      super
    end

    def drop_database(*args)
      begin
        @_no_switch = true
        super
      ensure
        @_no_switch = false
      end
    end

    def create_database(*args)
      begin
        @_no_switch = true
        super
      ensure
        @_no_switch = false
      end
    end

    def disconnect!
      @_cached_current_database = nil
      @_cached_connection_object_id = nil
      super
    end

    private

    def _switch_connection
      if _host_pool_current_database && ((_host_pool_current_database != @_cached_current_database) || @connection.object_id != @_cached_connection_object_id)
        log("select_db #{_host_pool_current_database}", "SQL") do
          clear_cache! if respond_to?(:clear_cache!)
          raw_connection.select_db(_host_pool_current_database)
          @config[:database] = _host_pool_current_database if ActiveRecord::VERSION::MAJOR >= 5
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
      def establish_connection(owner, spec)
        if ActiveRecord::VERSION::MAJOR >= 4
          @class_to_pool.clear
          raise RuntimeError, "Anonymous class is not allowed." unless owner.name
          owner_to_pool[owner.name] = ActiveRecordHostPool::PoolProxy.new(spec)
        elsif ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR == 2
          @connection_pools[spec] ||= ActiveRecordHostPool::PoolProxy.new(spec)
          @class_to_pool[owner] = @connection_pools[spec]
        else
          @connection_pools[owner] = ActiveRecordHostPool::PoolProxy.new(spec)
        end
      end
    end
  end
end

["MysqlAdapter", "Mysql2Adapter"].each do |k|
  next unless ActiveRecord::ConnectionAdapters.const_defined?(k)
  ActiveRecord::ConnectionAdapters.const_get(k).class_eval { prepend ActiveRecordHostPool::DatabaseSwitch }
end
