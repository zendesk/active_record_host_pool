module ActiveRecordHostPool
  module DatabaseSwitch
    def self.included(base)
      base.class_eval do
        attr_accessor(:_host_pool_current_database)
        alias_method_chain :execute, :switching
      end
    end


    def execute_with_switching(*args)
      if _host_pool_current_database
        _switch_connection
      end
      execute_without_switching(*args)
    end

    private

    def _switch_connection
      if raw_connection.respond_to?(:select_db)
        raw_connection.select_db(_host_pool_current_database)
      else
        execute_without_switching("use #{self._host_pool_current_database}")
      end
    end
  end
end

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandler
      def establish_connection(name, spec)
        @connection_pools[name] = ActiveRecordHostPool::PoolProxy.new(spec)
      end
    end
  end
end
