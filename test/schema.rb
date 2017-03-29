# frozen_string_literal: true

require_relative 'helper'
ActiveRecord::Schema.define(version: 1) do
  create_table 'tests' do |t|
    t.string   'val'
  end
end
