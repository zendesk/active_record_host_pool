# frozen_string_literal: true

module ActiveRecordHostPool
  class << self
    attr_accessor :loaded_adapter

    def mysql2?
      loaded_adapter == :mysql2
    end

    def database_error_class
      if mysql2?
        Mysql2::Error
      else
        Trilogy::Error
      end
    end
  end
end

begin
  require 'mysql2'
  ActiveRecordHostPool.loaded_adapter = :mysql2
rescue LoadError
  ActiveRecordHostPool.loaded_adapter = :trilogy
end

require 'active_record'
require 'active_record/base'
require 'active_record/connection_adapters/abstract_adapter'

require 'active_record_host_pool/clear_query_cache_patch'
require 'active_record_host_pool/connection_proxy'
require 'active_record_host_pool/pool_proxy'
require 'active_record_host_pool/connection_adapter_mixin'
require 'active_record_host_pool/version'
