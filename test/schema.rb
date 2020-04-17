# frozen_string_literal: true

require_relative 'helper'
ActiveRecord::Schema.define(version: 1) do
  create_table 'tests', force: true do |t|
    t.string   'val'
  end
end
