# frozen_string_literal: true

class ChatMessage < ApplicationRecord
  belongs_to :chat_room, touch: true
  belongs_to :user

  validates :content, presence: true

  # Живое и частичное обновление данных в реальном времени через Active Cable WebSockets + Turbo Streams
  after_create_commit -> {
    broadcast_append_to(
      chat_room,
      target: "chat_messages_list_#{chat_room.id}",
      partial: "chat_messages/message",
      locals: { message: self }
    )
  }
end
