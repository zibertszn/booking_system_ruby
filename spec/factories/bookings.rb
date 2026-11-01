# frozen_string_literal: true

FactoryBot.define do
  factory :booking do
    association :user
    association :resource

    booking_date  { Date.today + 1 }
    start_time    { "10:00" }
    end_time      { "12:00" }
    contact_name  { "Иван Иванов" }
    contact_email { "ivan@example.com" }
    contact_phone { "+7 (999) 111-11-11" }
    purpose       { "Встреча команды" }
    status        { "confirmed" }
  end
end
