require 'delegate'

# the ConnectionProxy sits between user-code and a real connection and says "I expect to be on this database"
# for each call to the connection.  upon executing a statement, the connection will switch to that database.
module ActiveRecordHostPool
  class ConnectionProxy < Delegator
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

    private
    def select(*args)
      @cx.__send__(:select, *args)
    end
  end
end


