# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'

require 'active_record_host_pool'
require 'logger'
require 'mocha/setup'
require 'phenix'

RAILS_ENV = 'test'

Minitest::Test = MiniTest::Unit::TestCase unless defined?(::Minitest::Test)

ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + '/test.log')

Phenix.configure do |config|
  config.skip_database = ->(name, conf) { name =~ /not_there/ || conf['username'] == 'john-doe' }
end

module ARHPTestSetup
  private

  def arhp_create_models
    return if ARHPTestSetup.const_defined?('Test1')

    eval <<-RUBY
      class Test1 < ActiveRecord::Base
        self.table_name = "tests"
        establish_connection(:test_host_1_db_1)
      end

      class Test1Slave < ActiveRecord::Base
        self.table_name = "tests"
        establish_connection(:test_host_1_db_1_slave)
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
    RUBY
  end

  def current_database(klass)
    klass.connection.select_value('select DATABASE()')
  end
end
