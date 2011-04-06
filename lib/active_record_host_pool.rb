require 'active_record'
require 'active_record/base'

require 'delegate'

module ActiveRecordHostPool
  class ConnectionProxy
    def initialize(cx, database)
      @cx = cx
      @database = database
    end

    def method_missing(m, *args, &block)
      target = @cx
      begin
        target._host_pool_current_database = @database
        target.respond_to?(m) ? target.__send__(m, *args, &block) : super(m, *args, &block)
      ensure
        $@.delete_if {|t| %r"\A#{Regexp.quote(__FILE__)}:#{__LINE__-2}:"o =~ t} if $@
      end
    end
  end

  class PoolProxy < Delegator
    def initialize(spec)
      @spec = spec
      @config = spec.config.with_indifferent_access
    end

    def __getobj__
      _connection_pool
    end

    def connection(*args)
      cx = _connection_pool.connection(*args)
      if !cx.respond_to?(:_host_pool_current_database)
        cx.class.class_eval { include ActiveRecordHostPool::DatabaseSwitch }
      end
      ActiveRecordHostPool::ConnectionProxy.new(cx, @config[:database])
    end

  private
    def _connection_pools
      @@connection_pools ||= {}
    end

    def _pool_key
      [@config[:host], @config[:port], @config[:socket]]
    end

    def _connection_pool
      pool = _connection_pools[_pool_key]
      if pool.nil?
        pool = _connection_pools[_pool_key] = ActiveRecord::ConnectionAdapters::ConnectionPool.new(@spec)
      end
      pool
    end
  end

  module DatabaseSwitch
    def self.included(base)
      base.class_eval do
        attr_accessor(:_host_pool_current_database)
        alias_method_chain :execute, :switching
      end
    end

    def execute_with_switching(*args)
      if self._host_pool_current_database
        if self.respond_to?(:select_db)
          self.select_db(self._host_pool_current_database)
        else
          self.execute_without_switching("use #{self._host_pool_current_database}")
        end
      end
      execute_without_switching(*args)
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
