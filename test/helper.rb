require 'bundler/setup'
require 'minitest/autorun'

require 'active_record_host_pool'
require 'logger'
require 'mocha/setup'
require 'erb'

RAILS_ENV = "test"

Minitest::Test = MiniTest::Unit::TestCase unless defined?(::Minitest::Test)

ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/test.log")

config_content = IO.read(File.dirname(__FILE__) + '/database.yml')
config_content = ERB.new(config_content).result
config =  YAML.load(config_content)

ActiveRecord::Base.configurations = config

module ARHPTestSetup
  private
  def arhp_create_databases
    for_each_database do |name, conf|
      run_mysql_command(conf, "CREATE DATABASE #{conf['database']}")
      ActiveRecord::Base.establish_connection(name.to_sym)
      ActiveRecord::Migration.verbose = false
      load(File.dirname(__FILE__) + "/schema.rb")
    end
  end

  def arhp_drop_databases
    for_each_database do |name, conf|
      run_mysql_command(conf, "DROP DATABASE IF EXISTS #{conf['database']}")
    end
  end

  def arhp_create_models
    return if Object.const_defined?("Test1")
    eval <<-EOL
      class Test1 < ActiveRecord::Base
        self.table_name = "tests"
        establish_connection(:test_host_1_db_1)
      end

      class Test2 < ActiveRecord::Base
        self.table_name =  "tests"
        establish_connection(:test_host_1_db_2)
      end

      class Test3 < ActiveRecord::Base
        self.table_name = "tests"
        establish_connection(:test_host_2_db_3)
      end

      class Test4 < ActiveRecord::Base
        self.table_name = "tests"
        establish_connection(:test_host_2_db_4)
      end

      class Test5 < ActiveRecord::Base
        self.table_name = "tests"
        establish_connection(:test_host_2_db_5)
      end
    EOL
  end

  def for_each_database
    ActiveRecord::Base.configurations.each do |name, conf|
      next if name =~ /not_there/
      next if conf['username'] == 'travis'
      yield(name, conf)
    end
  end

  def run_mysql_command(conf, command)
    @mysql_command ||= begin
      commands = [
        'mysql',
        "--user=#{conf['username']}"
      ]
      commands << "--host=#{conf['host']}" if conf['host'].present?
      commands << "--port=#{conf['port']}" if conf['port'].present?
      commands << " --password=#{conf['password']} 2> /dev/null" if conf['password'].present?
      commands.join(' ')
    end
    `echo "#{command}" | #{@mysql_command}`
  end

  def current_database(klass)
    klass.connection.select_value("select DATABASE()")
  end
end
