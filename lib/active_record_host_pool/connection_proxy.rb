# the ConnectionProxy sits between user-code and a real connection and says "I expect to be on this database"
# for each call to the connection.  upon executing a statement, the connection will switch to that database.
module ActiveRecordHostPool
  class ConnectionProxy
    def initialize(cx, database)
      @cx = cx
      @database = database
    end

    def __getobj__
      @cx
    end

    def method_missing(m, *args, &block)
      target = self.__getobj__
      begin
        target._host_pool_current_database = @database
        target.respond_to?(m) ? target.__send__(m, *args, &block) : super(m, *args, &block)
      ensure
        $@.delete_if {|t| %r"\A#{Regexp.quote(__FILE__)}:#{__LINE__-2}:"o =~ t} if $@
      end
    end
  end
end


