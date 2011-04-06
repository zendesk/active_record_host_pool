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

    # this enables mocha and friends as well as folks who monkey patch execute() to work.
    ActiveRecord::ConnectionAdapters::AbstractAdapter.instance_methods.each do |method|
      class_eval <<-EOL
        def #{method}(*args, &block)
          method_missing(:#{method}, *args, &block)
        end
      EOL
    end
  end
end


