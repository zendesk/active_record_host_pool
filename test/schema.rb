# frozen_string_literal: true

require_relative 'helper'
ActiveRecord::Schema.define(version: 1) do
  create_table 'tests', force: true do |t|
    t.string   'val'
  end

  # Add a table only the shard database will have. Conditional
  # exists since Phenix loads the schema file for every database.
  if ActiveRecord::Base.connection.current_database == 'arhp_test_1_shard'
    create_table 'test1_shards' do |t|
      t.string 'name'
    end
  end
end
