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

Phenix.rise! config_path: "test/three_tier_database.yml"
require_relative "models"

module ARHPTestSetup
  private

  def delete_all_records
    Pool1DbC.delete_all
    Pool1DbA.delete_all
    Pool1DbAOther.delete_all
    Pool1DbB.delete_all
    Pool2DbD.delete_all
    Pool2DbE.delete_all
    Pool3DbE.delete_all

    AbstractShardedModel.connected_to(shard: :default, role: :writing) { ShardedModel.delete_all }
    AbstractShardedModel.connected_to(shard: :shard_b, role: :writing) { ShardedModel.delete_all }
    AbstractShardedModel.connected_to(shard: :shard_c, role: :writing) { ShardedModel.delete_all }
    AbstractShardedModel.connected_to(shard: :shard_b, role: :writing) { ShardedModel.delete_all }
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
