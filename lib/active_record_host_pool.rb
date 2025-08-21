# frozen_string_literal: true

require "active_record"
require "active_record/base"
require "active_record/connection_adapters/abstract_adapter"

begin
  require "mysql2"
rescue LoadError
  :noop
end

begin
  require "trilogy"
rescue LoadError
  :noop
end

require "active_record_host_pool/connection_proxy"
require "active_record_host_pool/pool_proxy"
require "active_record_host_pool/connection_adapter_mixin"
require "active_record_host_pool/version"
