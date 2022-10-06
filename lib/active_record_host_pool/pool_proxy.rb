# frozen_string_literal: true

case "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"
when '6.1', '7.0'
  require 'active_record_host_pool/pool_proxy_6_1'
else
  require 'active_record_host_pool/pool_proxy_legacy'
end
