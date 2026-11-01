# frozen_string_literal: true

FactoryBot.define do
  factory :chat_room do
    sequence(:title) { |n| "Диалог 1 на 1 #{n}" }
    association :customer, factory: :user
    association :owner, factory: :user
    association :resource, factory: :resource
  end
end
