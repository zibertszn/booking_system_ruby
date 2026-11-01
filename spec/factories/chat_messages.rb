# frozen_string_literal: true

FactoryBot.define do
  factory :chat_message do
    association :chat_room
    association :user
    content { "Привет! Это тестовое сообщение в чат." }
  end
end
