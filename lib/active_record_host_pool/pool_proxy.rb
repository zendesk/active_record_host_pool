# frozen_string_literal: true

if "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}" == '6.1'
  require 'active_record_host_pool/pool_proxy_6_1'
else
  require 'active_record_host_pool/pool_proxy_legacy'
end
