# frozen_string_literal: true

require_relative 'helper'

begin
  ActiveRecordHostPool.allowing_writes = true

  ActiveRecord::Schema.define(version: 1) do
    create_table 'tests', force: true do |t|
      t.string   'val'
    end

    # Add a table only the shard database will have. Conditional
    # exists since Phenix loads the schema file for every database.
    if ActiveRecord::Base.connection.current_database == 'arhp_test_db_c'
      create_table 'pool1_db_cs' do |t|
        t.string 'name'
      end
    end
  end
ensure
  ActiveRecordHostPool.allowing_writes = false
end
