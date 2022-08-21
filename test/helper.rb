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

ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + '/test.log')

# BEGIN preventing_writes? patch
## Rails 6.1 by default does not allow writing to replica databases which prevents
## us from properly setting up the test databases. This patch is used in test/schema.rb
## to allow us to write to the replicas but only during migrations
module ActiveRecordHostPool
  cattr_accessor :allowing_writes
  module PreventWritesPatch
    def preventing_writes?
      return false if ActiveRecordHostPool.allowing_writes && replica?

      super
    end
  end
end

if ActiveRecord.version >= Gem::Version.new('6.1')
  ActiveRecord::ConnectionAdapters::AbstractAdapter.prepend ActiveRecordHostPool::PreventWritesPatch
end
# END preventing_writes? patch

Phenix.configure do |config|
  config.skip_database = ->(name, conf) { name =~ /not_there/ || conf['username'] == 'john-doe' }
end

module ARHPTestSetup
  private

  def arhp_create_models
    return if ARHPTestSetup.const_defined?('Pool1DbA')

    if ActiveRecord.version >= Gem::Version.new('6.1') && !ActiveRecord::Base.legacy_connection_handling
      eval <<-RUBY
        class AbstractPool1DbC < ActiveRecord::Base
          self.abstract_class = true
          connects_to database: { writing: :test_pool_1_db_c }
        end

        # The placement of the Pool1DbC class is important so that its
        # connection will not be the most recent connection established
        # for test_pool_1.
        class Pool1DbC < AbstractPool1DbC
        end

        class AbstractPool1DbA < ActiveRecord::Base
          self.abstract_class = true
          connects_to database: { writing: :test_pool_1_db_a, reading: :test_pool_1_db_a_replica }
        end

        class Pool1DbA < AbstractPool1DbA
          self.table_name = "tests"
        end

        class AbstractPool1DbB < ActiveRecord::Base
          self.abstract_class = true
          connects_to database: { writing: :test_pool_1_db_b }
        end

        class Pool1DbB < AbstractPool1DbB
          self.table_name = "tests"
        end

        class AbstractShardedModel < ActiveRecord::Base
          self.abstract_class = true
          connects_to shards: {
                        default: { writing: :test_pool_1_db_shard_a },
                        shard_b: { writing: :test_pool_1_db_shard_b, reading: :test_pool_1_db_shard_b_replica },
                        shard_c: { writing: :test_pool_1_db_shard_c, reading: :test_pool_1_db_shard_c_replica },
                        shard_d: { writing: :test_pool_2_db_shard_d, reading: :test_pool_2_db_shard_d_replica }
                      }
        end

        class ShardedModel < AbstractShardedModel
          self.table_name = "tests"
        end

        class AbstractPool2DbD < ActiveRecord::Base
          self.abstract_class = true
          connects_to database: { writing: :test_pool_2_db_d }
        end

        class Pool2DbD < AbstractPool2DbD
          self.table_name = "tests"
        end

        class AbstractPool2DbE < ActiveRecord::Base
          self.abstract_class = true
          connects_to database: { writing: :test_pool_2_db_e }
        end

        class Pool2DbE < AbstractPool2DbE
          self.table_name = "tests"
        end

        class AbstractPool3DbE < ActiveRecord::Base
          self.abstract_class = true
          connects_to database: { writing: :test_pool_3_db_e }
        end

        class Pool3DbE < AbstractPool3DbE
          self.table_name = "tests"
        end
      RUBY
    else
      eval <<-RUBY
        # The placement of the Pool1DbC class is important so that its
        # connection will not be the most recent connection established
        # for test_pool_1.
        class Pool1DbC < ActiveRecord::Base
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
    if ActiveRecord.version < Gem::Version.new('6.1') || ENV['LEGACY_CONNECTION_HANDLING'] == 'true'
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
