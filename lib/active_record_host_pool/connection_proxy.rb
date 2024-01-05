# frozen_string_literal: true

require "delegate"

# the ConnectionProxy sits between user-code and a real connection and says "I expect to be on this database"
# for each call to the connection.  upon executing a statement, the connection will switch to that database.
module ActiveRecordHostPool
  class ConnectionProxy < Delegator
    attr_reader :database
    def initialize(cx, database)
      super(cx)
      @cx = cx
      @database = database
    end

    def __getobj__
      @cx._host_pool_current_database = @database
      @cx
    end

    def __setobj__(cx)
      @cx = cx
    end

    def unproxied
      @cx
    end

    # this is bad.  I know.  but it allows folks who class_eval on connection.class to do so
    def class
      @cx.class
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

    def send(symbol, *args, &blk)
      if respond_to?(symbol, true) && !__getobj__.respond_to?(symbol, true)
        super
      else
        __getobj__.send(symbol, *args, &blk)
      end
    end
    ruby2_keywords :send if respond_to?(:ruby2_keywords, true)

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

    def select(*args)
      @cx.__send__(:select, *args)
    end
    ruby2_keywords :select if respond_to?(:ruby2_keywords, true)
  end
end
