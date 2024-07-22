# frozen_string_literal: true

require "bundler/setup"
require "minitest/autorun"
require "pry-byebug"

require "active_record_host_pool"
require "logger"
require "minitest/mock_expectations"
require "phenix"

ENV["RAILS_ENV"] = "test"

ActiveRecord::Base.legacy_connection_handling = false if ActiveRecord::Base.respond_to?(:legacy_connection_handling)

ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/test.log")

Thread.abort_on_exception = true

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

ActiveRecord::ConnectionAdapters::AbstractAdapter.prepend(ActiveRecordHostPool::PreventWritesPatch)
# END preventing_writes? patch

Phenix.configure do |config|
  config.skip_database = ->(name, conf) { name =~ /not_there/ || conf["username"] == "john-doe" }
end

module ARHPTestSetup
  private

  def arhp_create_models
    return if ARHPTestSetup.const_defined?(:Pool1DbA)
    eval(<<-RUBY, binding, __FILE__, __LINE__ + 1)
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

        class Pool1DbAOther < AbstractPool1DbA
          self.table_name = "tests"
        end

        class AbstractPool1DbB < ActiveRecord::Base
          self.abstract_class = true
          connects_to database: { writing: :test_pool_1_db_b }
        end

        class Pool1DbB < AbstractPool1DbB
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

        # Test ARHP with Rails 6.1+ horizontal sharding functionality
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
    RUBY
  end

  def current_database(klass)
    klass.connection.select_value("select DATABASE()")
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
