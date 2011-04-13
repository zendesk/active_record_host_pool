require 'delegate'

# the ConnectionProxy sits between user-code and a real connection and says "I expect to be on this database"
# for each call to the connection.  upon executing a statement, the connection will switch to that database.
module ActiveRecordHostPool
  class ConnectionProxy < Delegator
    def initialize(cx, database)
      @cx = cx
      @database = database
    end

    def __getobj__
      @cx._host_pool_current_database = @database
      @cx
    end

    def unproxied
      @cx
    end

    def self.class_eval(*args, &block)
      @cx.class.class_eval(*args, &block)
    end
  end
end


