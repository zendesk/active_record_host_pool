# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'

require 'active_record_host_pool'
require 'logger'
require 'mocha/minitest'
require 'phenix'

ENV['RAILS_ENV'] = 'test'
ENV['LEGACY_CONNECTION_HANDLING'] = 'true' if ENV['LEGACY_CONNECTION_HANDLING'].nil?

if ActiveRecord.version >= Gem::Version.new('6.1')
  ActiveRecord::Base.legacy_connection_handling = (ENV['LEGACY_CONNECTION_HANDLING'] == 'true')
end

RAILS_6_1_WITH_NON_LEGACY_CONNECTION_HANDLING =
  ActiveRecord.version >= Gem::Version.new('6.1') && !ActiveRecord::Base.legacy_connection_handling

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

  def simulate_rails_app_active_record_railties
    if ActiveRecord.version >= Gem::Version.new('6.0')
      # Necessary for testing ActiveRecord 6.0 which uses the connection
      # handlers when clearing query caches across all handlers when
      # an operation that dirties the cache is involved (e.g. create/insert,
      # update, delete/destroy, truncate, etc.)
      ActiveRecord::Base.connection_handlers = {
        ActiveRecord::Base.writing_role => ActiveRecord::Base.default_connection_handler
      }
    end
  end
end
