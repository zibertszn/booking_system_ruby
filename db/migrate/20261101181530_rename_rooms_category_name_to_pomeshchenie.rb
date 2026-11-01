# frozen_string_literal: true

class RenameRoomsCategoryNameToPomeshchenie < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      UPDATE resources
      SET category_name = 'Помещение'
      WHERE category = 'rooms';
    SQL
  end

  def down
    execute <<~SQL
      UPDATE resources
      SET category_name = 'Переговорные комнаты'
      WHERE category = 'rooms';
    SQL
  end
end
