# frozen_string_literal: true

class AddUserIdToResources < ActiveRecord::Migration[7.1]
  def change
    add_reference :resources, :user, foreign_key: true, index: true
  end
end
