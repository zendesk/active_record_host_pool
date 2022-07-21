# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'

require 'active_record_host_pool'
require 'logger'
require 'mocha/setup'
require 'phenix'

RAILS_ENV = 'test'
ENV["RAILS_ENV"] = RAILS_ENV

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
      # The placement of the Test1Shard class is important so that its
      # connection will not be the most recent connection established
      # for test_host_1.

      class Test1ShardRecord < ActiveRecord::Base
        self.abstract_class = true
        connects_to database: { writing: :test_host_1_db_shard }
      end

      class Test1Shard < Test1ShardRecord
      end

      class Test1Record < ActiveRecord::Base
        self.abstract_class = true
        connects_to database: { writing: :primary, reading: :primary_replica }
      end

      class Test1 < Test1Record
        self.table_name = "tests"
      end

      class Test1Slave < Test1Record
        self.table_name = "tests"
      end

      class Test2Record < ActiveRecord::Base
        self.abstract_class = true
        connects_to database: { writing: :test_host_1_db_2 }
      end

      class Test2 < Test2Record
        self.table_name = "tests"
      end

      class Test3Record < ActiveRecord::Base
        self.abstract_class = true
        connects_to database: { writing: :test_host_2_db_3 }
      end

      class Test3 < Test3Record
        self.table_name = "tests"
      end

      class Test4Record < ActiveRecord::Base
        self.abstract_class = true
        connects_to database: { writing: :test_host_2_db_4 }
      end

      class Test4 < Test4Record
        self.table_name = "tests"
      end


      class Test5Record < ActiveRecord::Base
        self.abstract_class = true
        connects_to database: { writing: :test_host_2_db_5 }
      end

      class Test5 < Test5Record
        self.table_name = "tests"
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
