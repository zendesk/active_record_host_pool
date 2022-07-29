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
    return if ARHPTestSetup.const_defined?('Pool1DbA')

    eval <<-RUBY
      # The placement of the Pool1DbC class is important so that its
      # connection will not be the most recent connection established
      # for test_pool_1.
      class Pool1DbC < ::ActiveRecord::Base
        establish_connection(:test_pool_1_db_c)
      end

      class Pool1DbA < ActiveRecord::Base
        self.table_name = "tests"
        establish_connection(:test_pool_1_db_a)
      end

      class Pool1DbAReplica < ActiveRecord::Base
        self.table_name = "tests"
        establish_connection(:test_pool_1_db_a_replica)
      end

      class Pool1DbB < ActiveRecord::Base
        self.table_name =  "tests"
        establish_connection(:test_pool_1_db_b)
      end

      class Pool2DbD < ActiveRecord::Base
        self.table_name = "tests"
        establish_connection(:test_pool_2_db_d)
      end

      class Pool2DbE < ActiveRecord::Base
        self.table_name = "tests"
        establish_connection(:test_pool_2_db_e)
      end

      class Pool3DbE < ActiveRecord::Base
        self.table_name = "tests"
        establish_connection(:test_pool_3_db_e)
      end
    RUBY
  end

  def current_database(klass)
    klass.connection.select_value('select DATABASE()')
  end

  # Remove a method from a given module that fixes something.
  # Execute the passed in block.
  # Re-add the method back to the module.
  def without_module_patch(mod, method_name)
    method_body = mod.instance_method(method_name)
    mod.remove_method(method_name)
    yield if block_given?
  ensure
    mod.define_method(method_name, method_body)
  end
end
