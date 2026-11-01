# frozen_string_literal: true

class CreateResources < ActiveRecord::Migration[7.1]
  def change
    create_table :resources do |t|
      t.string  :slug,          null: false
      t.string  :name,          null: false
      t.string  :category,      null: false
      t.string  :category_name, null: false
      t.text    :description,   null: false
      t.string  :location
      t.integer :capacity
      t.integer :hourly_rate,   null: false
      t.string  :amenities,     array: true, default: []
      t.string  :image_url

      t.timestamps
    end

    add_index :resources, :slug, unique: true
    add_index :resources, :category
  end
end
