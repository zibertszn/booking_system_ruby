# frozen_string_literal: true

class AddParticipantsAndResourceToChatRooms < ActiveRecord::Migration[7.1]
  def change
    execute "DELETE FROM chat_messages"
    execute "DELETE FROM chat_rooms"

    add_reference :chat_rooms, :customer, null: false, foreign_key: { to_table: :users }, index: true
    add_reference :chat_rooms, :owner, null: false, foreign_key: { to_table: :users }, index: true
    add_reference :chat_rooms, :resource, foreign_key: true, index: true

    add_index :chat_rooms, [:customer_id, :owner_id, :resource_id]
  end
end
