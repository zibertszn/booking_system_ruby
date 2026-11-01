# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Booking, type: :model do
  # --- Ассоциации ---
  describe "ассоциации" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:resource) }
  end

  # --- Валидации (shoulda-matchers) ---
  describe "валидации" do
    it { is_expected.to validate_presence_of(:booking_date) }
    it { is_expected.to validate_presence_of(:contact_name) }
    it { is_expected.to validate_presence_of(:contact_email) }
    it { is_expected.to validate_inclusion_of(:status).in_array(Booking::STATUSES) }
  end

  # --- Фабрика ---
  describe "фабрика" do
    it "создаёт валидное бронирование" do
      expect(build(:booking)).to be_valid
    end
  end

  # --- Валидация времени ---
  describe "end_time_after_start_time" do
    it "невалидно если end_time <= start_time" do
      booking = build(:booking, start_time: "12:00", end_time: "10:00")
      expect(booking).not_to be_valid
      expect(booking.errors[:end_time]).to include("должно быть позже времени начала")
    end

    it "невалидно если end_time == start_time" do
      booking = build(:booking, start_time: "10:00", end_time: "10:00")
      expect(booking).not_to be_valid
    end

    it "валидно если end_time > start_time" do
      booking = build(:booking, start_time: "10:00", end_time: "12:00")
      expect(booking).to be_valid
    end
  end

  # --- Валидация бронирования внутри интервала доступности ресурса ---
  describe "booking_within_resource_availability" do
    let(:resource) do
      create(
        :resource,
        available_from_time: "10:00",
        available_to_time: "18:00",
        available_from_date: Date.current,
        available_to_date: Date.current + 7.days
      )
    end

    it "валидно когда время бронирования попадает в интервал доступности" do
      booking = build(:booking, resource: resource, booking_date: Date.current + 1.day, start_time: "11:00", end_time: "13:00")
      expect(booking).to be_valid
    end

    it "не валидно когда start_time раньше available_from_time" do
      booking = build(:booking, resource: resource, booking_date: Date.current + 1.day, start_time: "09:00", end_time: "11:00")
      expect(booking).not_to be_valid
      expect(booking.errors[:base].join).to include("Бронирование возможно только в интервале доступности с 10:00 до 18:00")
    end

    it "не валидно когда end_time позже available_to_time" do
      booking = build(:booking, resource: resource, booking_date: Date.current + 1.day, start_time: "17:00", end_time: "19:00")
      expect(booking).not_to be_valid
      expect(booking.errors[:base].join).to include("Бронирование возможно только в интервале доступности с 10:00 до 18:00")
    end

    it "не валидно когда дата бронирования раньше available_from_date" do
      booking = build(:booking, resource: resource, booking_date: Date.current - 1.day, start_time: "11:00", end_time: "12:00")
      expect(booking).not_to be_valid
      expect(booking.errors[:booking_date].join).to include("не может быть раньше начала периода доступности")
    end

    it "не валидно когда дата бронирования позже available_to_date" do
      booking = build(:booking, resource: resource, booking_date: Date.current + 10.days, start_time: "11:00", end_time: "12:00")
      expect(booking).not_to be_valid
      expect(booking.errors[:booking_date].join).to include("не может быть позже окончания периода доступности")
    end
  end

  # --- Запрет бронирования собственного объявления ---
  describe "user_cannot_book_own_resource" do
    let(:owner) { create(:user, name: "Владелец объявления") }
    let(:renter) { create(:user, name: "Арендатор") }
    let(:resource) { create(:resource, user: owner) }

    it "запрещает владельцу бронировать свое собственное объявление" do
      booking = build(:booking, user: owner, resource: resource)
      expect(booking).not_to be_valid
      expect(booking.errors[:base]).to include("Вы не можете забронировать собственное объявление")
    end

    it "разрешает бронирование другому пользователю" do
      booking = build(:booking, user: renter, resource: resource)
      expect(booking).to be_valid
    end
  end

  # --- Вычисляемые поля ---
  describe "#compute_timestamps_and_price (before_validation)" do
    let(:resource) { create(:resource, hourly_rate: 1000) }

    it "рассчитывает total_price на основе hourly_rate и длительности" do
      booking = build(:booking, resource: resource, start_time: "10:00", end_time: "12:00")
      booking.valid?
      expect(booking.total_price).to eq(2000)
    end

    it "рассчитывает duration_hours" do
      booking = build(:booking, resource: resource, start_time: "09:00", end_time: "12:00")
      booking.valid?
      expect(booking.duration_hours).to eq(3)
    end

    it "минимальная длительность — 1 час" do
      booking = build(:booking, resource: resource, start_time: "10:00", end_time: "10:30")
      booking.valid?
      expect(booking.duration_hours).to eq(1)
    end

    it "устанавливает starts_at и ends_at" do
      date = Date.today + 1
      booking = build(:booking, resource: resource, booking_date: date,
                      start_time: "10:00", end_time: "12:00")
      booking.valid?
      expect(booking.starts_at.hour).to eq(10)
      expect(booking.ends_at.hour).to eq(12)
    end
  end

  # --- Пересечение бронирований ---
  describe "no_overlapping_confirmed_bookings" do
    let(:resource) { create(:resource) }
    let(:date)     { Date.today + 2 }

    it "не позволяет создать пересекающееся подтверждённое бронирование" do
      create(:booking, resource: resource, booking_date: date,
             start_time: "10:00", end_time: "12:00", status: "confirmed")

      overlapping = build(:booking, resource: resource, booking_date: date,
                          start_time: "11:00", end_time: "13:00", status: "confirmed")
      expect(overlapping).not_to be_valid
      expect(overlapping.errors[:base].first).to include("уже занят")
    end

    it "разрешает бронирование на другой временной интервал" do
      create(:booking, resource: resource, booking_date: date,
             start_time: "10:00", end_time: "12:00", status: "confirmed")

      non_overlapping = build(:booking, resource: resource, booking_date: date,
                              start_time: "12:00", end_time: "14:00", status: "confirmed")
      expect(non_overlapping).to be_valid
    end

    it "разрешает отменённое бронирование поверх существующего" do
      create(:booking, resource: resource, booking_date: date,
             start_time: "10:00", end_time: "12:00", status: "confirmed")

      cancelled = build(:booking, resource: resource, booking_date: date,
                        start_time: "10:00", end_time: "12:00", status: "cancelled")
      expect(cancelled).to be_valid
    end
  end

  # --- .time_to_minutes ---
  describe ".time_to_minutes" do
    it "конвертирует '10:30' в 630 минут" do
      expect(Booking.time_to_minutes("10:30")).to eq(630)
    end

    it "конвертирует '00:00' в 0 минут" do
      expect(Booking.time_to_minutes("00:00")).to eq(0)
    end

    it "конвертирует '23:59' в 1439 минут" do
      expect(Booking.time_to_minutes("23:59")).to eq(1439)
    end
  end

  # --- #overlaps_hours? ---
  describe "#overlaps_hours?" do
    let(:booking) { build(:booking, start_time: "10:00", end_time: "12:00") }

    it "возвращает true при пересечении" do
      expect(booking.overlaps_hours?("11:00", "13:00")).to be true
    end

    it "возвращает false при смежных интервалах" do
      expect(booking.overlaps_hours?("12:00", "14:00")).to be false
    end

    it "возвращает false при непересекающихся интервалах" do
      expect(booking.overlaps_hours?("08:00", "10:00")).to be false
    end
  end

  # --- Скоупы ---
  describe "скоупы" do
    let!(:confirmed) { create(:booking, status: "confirmed") }
    let!(:cancelled) { create(:booking, status: "cancelled") }

    it ".confirmed возвращает только подтверждённые" do
      expect(Booking.confirmed).to include(confirmed)
      expect(Booking.confirmed).not_to include(cancelled)
    end

    it ".cancelled возвращает только отменённые" do
      expect(Booking.cancelled).to include(cancelled)
      expect(Booking.cancelled).not_to include(confirmed)
    end
  end

  # --- #cancel! ---
  describe "#cancel!" do
    it "меняет статус на cancelled" do
      booking = create(:booking, status: "confirmed")
      # Глушим мейлер чтобы не отправлял письма в тестах
      allow(BookingMailer).to receive_message_chain(:cancellation_email, :deliver_later)
      booking.cancel!
      expect(booking.reload.status).to eq("cancelled")
    end
  end
end
