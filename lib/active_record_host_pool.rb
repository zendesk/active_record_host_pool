# frozen_string_literal: true

module ActiveRecordHostPool
  class << self
    attr_accessor :loaded_db_adapter
  end
end

begin
  require "mysql2"
  ActiveRecordHostPool.loaded_db_adapter = :mysql2
rescue LoadError
  require "activerecord-trilogy-adapter"
  ActiveRecordHostPool.loaded_db_adapter = :trilogy
end

require "active_record"
require "active_record/base"
require "active_record/connection_adapters/abstract_adapter"

require "active_record_host_pool/clear_query_cache_patch"
require "active_record_host_pool/connection_proxy"
require "active_record_host_pool/pool_proxy"
require "active_record_host_pool/connection_adapter_mixin"
require "active_record_host_pool/version"
