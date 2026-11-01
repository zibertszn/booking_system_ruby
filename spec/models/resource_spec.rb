# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Resource, type: :model do
  # --- Ассоциации ---
  describe "ассоциации" do
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to have_many(:bookings).dependent(:destroy) }
  end

  # --- Валидации (shoulda-matchers) ---
  describe "валидации" do
    # Для validate_uniqueness_of нужна заранее сохранённая запись
    subject { create(:resource) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_presence_of(:category) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:hourly_rate) }
    it { is_expected.to validate_uniqueness_of(:slug) }
    it { is_expected.to validate_numericality_of(:hourly_rate).is_greater_than(0) }
    it { is_expected.to validate_inclusion_of(:category).in_array(Resource::CATEGORIES.keys) }
  end

  # --- Фабрика ---
  describe "фабрика" do
    it "создаёт валидный ресурс" do
      expect(build(:resource)).to be_valid
    end

    it "не валиден с неизвестной категорией" do
      expect(build(:resource, category: "unknown")).not_to be_valid
    end

    it "не валиден с нулевой ценой" do
      expect(build(:resource, hourly_rate: 0)).not_to be_valid
    end

    it "не валиден с отрицательной ценой" do
      expect(build(:resource, hourly_rate: -100)).not_to be_valid
    end
  end

  # --- Callback: автозаполнение slug и category_name ---
  describe "#assign_default_slug_and_category_name" do
    it "автоматически заполняет category_name из CATEGORIES" do
      resource_eq = build(:resource, category: "equipment", category_name: nil)
      resource_eq.valid?
      expect(resource_eq.category_name).to eq("Оборудование")

      resource_room = build(:resource, category: "rooms", category_name: nil)
      resource_room.valid?
      expect(resource_room.category_name).to eq("Помещение")
    end

    it "генерирует slug если он пуст" do
      resource = build(:resource, slug: "", name: "Тест")
      resource.valid?
      expect(resource.slug).to match(/\Ares_\d+_\d+\z/)
    end

    it "не перезаписывает slug если он уже задан" do
      resource = build(:resource, slug: "my-custom-slug")
      resource.valid?
      expect(resource.slug).to eq("my-custom-slug")
    end
  end

  # --- Константы ---
  describe "CATEGORIES" do
    it "содержит rooms, equipment, specialists" do
      expect(Resource::CATEGORIES.keys).to match_array(%w[rooms equipment specialists])
    end
  end

  describe "RATE_UNITS" do
    it "содержит hour, day, month, year" do
      expect(Resource::RATE_UNITS.keys).to match_array(%w[hour day month year])
    end

    it "позволяет задавать ставку в час/день/месяц/год для помещений" do
      %w[hour day month year].each do |unit|
        res = build(:resource, category: "rooms", rate_unit: unit)
        expect(res).to be_valid
        expect(res.rate_unit).to eq(unit)
      end
    end

    it "позволяет задавать ставку в час/день/месяц/год для оборудования" do
      %w[hour day month year].each do |unit|
        res = build(:resource, category: "equipment", rate_unit: unit)
        expect(res).to be_valid
        expect(res.rate_unit).to eq(unit)
      end
    end

    it "нормализует rate_unit в hour для специалистов" do
      res = build(:resource, category: "specialists", rate_unit: "month")
      res.valid?
      expect(res.rate_unit).to eq("hour")
    end

    it "сохраняет capacity для помещений и очищает для оборудования и специалистов" do
      room = build(:resource, category: "rooms", capacity: 10)
      room.valid?
      expect(room.capacity).to eq(10)

      eq = build(:resource, category: "equipment", capacity: 5)
      eq.valid?
      expect(eq.capacity).to be_nil

      spec = build(:resource, category: "specialists", capacity: 3)
      spec.valid?
      expect(spec.capacity).to be_nil
    end

    it "рассчитывает effective_hourly_rate для дневной, месячной и годовой ставки" do
      room_day = build(:resource, category: "rooms", hourly_rate: 12000, rate_unit: "day")
      expect(room_day.effective_hourly_rate).to eq(1000)

      room_month = build(:resource, category: "rooms", hourly_rate: 52800, rate_unit: "month")
      expect(room_month.effective_hourly_rate).to eq(200)

      room_hour = build(:resource, category: "rooms", hourly_rate: 1500, rate_unit: "hour")
      expect(room_hour.effective_hourly_rate).to eq(1500)
    end
  end

  # --- Скоупы ---
  describe "скоупы" do
    let!(:room)      { create(:resource, category: "rooms") }
    let!(:equipment) { create(:resource, category: "equipment") }

    describe ".by_category" do
      it "фильтрует по категории" do
        expect(Resource.by_category("rooms")).to include(room)
        expect(Resource.by_category("rooms")).not_to include(equipment)
      end

      it "возвращает все при category=all" do
        expect(Resource.by_category("all")).to include(room, equipment)
      end

      it "возвращает все при пустой категории" do
        expect(Resource.by_category("")).to include(room, equipment)
      end
    end

    describe ".search_query" do
      it "находит ресурс по части имени" do
        r = create(:resource, name: "Зал Орион")
        expect(Resource.search_query("Орион")).to include(r)
      end

      it "возвращает все при пустом запросе" do
        expect(Resource.search_query("")).to include(room, equipment)
      end
    end
  end
end
