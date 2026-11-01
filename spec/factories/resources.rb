# frozen_string_literal: true

FactoryBot.define do
  factory :resource do
    sequence(:name)  { |n| "Ресурс #{n}" }
    sequence(:slug)  { |n| "resource-#{n}" }
    category      { "rooms" }
    category_name { "Помещение" }
    description   { "Описание тестового ресурса" }
    location      { "Этаж 1" }
    hourly_rate   { 500 }
    rate_unit     { "hour" }
    capacity      { 10 }
  end
end
