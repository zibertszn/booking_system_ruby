# frozen_string_literal: true

class AddRateUnitToResources < ActiveRecord::Migration[7.1]
  def change
    add_column :resources, :rate_unit, :string, default: "hour", null: false
  end
end
