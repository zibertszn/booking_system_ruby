# frozen_string_literal: true

class AddBookingTimeIntervalToResources < ActiveRecord::Migration[7.1]
  def change
    add_column :resources, :available_from_time, :string, default: "09:00", null: false
    add_column :resources, :available_to_time, :string, default: "21:00", null: false
    add_column :resources, :available_from_date, :date
    add_column :resources, :available_to_date, :date
  end
end
