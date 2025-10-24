# frozen_string_literal: true

require "testcontainers/mysql"

module TC
  class << self
    def start_mysql
      puts "Starting test containers"

      start_pool_1
      start_pool_2
    end

    def stop_mysql
      puts "Shutting down test containers"

      stop_pool_1
      stop_pool_2
    end

    attr_reader :pool_1, :pool_2

    private

    def start_pool_1
      @pool_1 = Testcontainers::MysqlContainer.new("mysql:8.0", name: "arhp_pool_1", username: "root", password: "")
      @pool_1.start
    rescue
      stop_pool_1
      raise
    end

    def start_pool_2
      @pool_2 = Testcontainers::MysqlContainer.new("mysql:8.0", name: "arhp_pool_2", username: "root", password: "")
      @pool_2.start

      sql =
        "CREATE USER 'john-doe';" \
        "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,INDEX ON *.* TO 'john-doe';" \
        "FLUSH PRIVILEGES;"
      system("mysql --host #{pool_2.host} --port #{pool_2.first_mapped_port} -uroot -e \"#{sql}\"")
    rescue
      stop_pool_2
      raise
    end

    def stop_pool_1
      @pool_1.stop if @pool_1.running?
      @pool_1.remove
    end

    def stop_pool_2
      @pool_2.stop if @pool_2.running?
      @pool_2.remove
    end
  end
end
