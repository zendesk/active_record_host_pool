# frozen_string_literal: true

require "delegate"

# the ConnectionProxy sits between user-code and a real connection and says "I expect to be on this database"
# for each call to the connection.  upon executing a statement, the connection will switch to that database.
module ActiveRecordHostPool
  class ConnectionProxy < Delegator
    class << self
      def class_eval
        raise "You probably want to call .class_eval on the ActiveRecord connection adapter and not on ActiveRecordHostPool's connection proxy. Use .arhp_connection_proxy_class_eval if you _really_ know what you're doing."
      end

      def arhp_connection_proxy_class_eval(...)
        method(:class_eval).super_method.call(...)
      end
    end

    attr_reader :database
    def initialize(cx, database)
      super(cx)
      @cx = cx
      @database = database
    end

    def __getobj__
      @cx._host_pool_desired_database = @database
      @cx
    end

    def __setobj__(cx)
      @cx = cx
    end

    def unproxied
      @cx
    end

    def expects(*args)
      @cx.send(:expects, *args)
    end

    # Override Delegator#respond_to_missing? to allow private methods to be accessed without warning
    def respond_to_missing?(name, include_private)
      __getobj__.respond_to?(name, include_private)
    end

    def private_methods(all = true)
      __getobj__.private_methods(all) | super
    end

    def send(symbol, ...)
      if respond_to?(symbol, true) && !__getobj__.respond_to?(symbol, true)
        super
      else
        __getobj__.send(symbol, ...)
      end
    end

    def ==(other)
      self.class == other.class &&
        other.respond_to?(:unproxied) && @cx == other.unproxied &&
        other.respond_to?(:database) && @database == other.database
    end

    alias_method :eql?, :==

    def hash
      [self.class, @cx, @database].hash
    end

    private

    def select(...)
      @cx.__send__(:select, ...)
    end
  end
end
