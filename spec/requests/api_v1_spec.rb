# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API v1 Integration", type: :request do
  around do |example|
    orig = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    example.run
    ActionController::Base.allow_forgery_protection = orig
  end

  let(:user) { create(:user) }
  let(:resource) { create(:resource, name: "Студия звукозаписи", hourly_rate: 2000) }
  let(:target_date) { (Date.current + 3).to_s }

  describe "GET /api/v1/resources/:id/availability" do
    it "возвращает 200 OK со списком всех рабочих слотов ресурса на указанную дату" do
      get "/api/v1/resources/#{resource.slug}/availability", params: { date: target_date }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      expect(data["resource_id"]).to eq(resource.id)
      expect(data["resource_name"]).to eq(resource.name)
      expect(data["hourly_rate"]).to eq(2000)
      expect(data["date"]).to eq(target_date)

      slots = data["slots"]
      expect(slots).to be_an(Array)
      expect(slots.size).to eq(Resource::BUSINESS_END_HOUR - Resource::BUSINESS_START_HOUR)
      expect(slots.all? { |s| s["available"] == true }).to be true
    end

    it "корректно отмечает занятые слоты при наличии подтвержденного бронирования" do
      create(
        :booking,
        user: user,
        resource: resource,
        status: "confirmed",
        booking_date: target_date,
        start_time: "11:00",
        end_time: "13:00",
        contact_name: "Иван Иванов"
      )

      get "/api/v1/resources/#{resource.slug}/availability", params: { date: target_date }
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      slot_10 = data["slots"].find { |s| s["time_label"] == "10:00" }
      slot_11 = data["slots"].find { |s| s["time_label"] == "11:00" }
      slot_12 = data["slots"].find { |s| s["time_label"] == "12:00" }
      slot_13 = data["slots"].find { |s| s["time_label"] == "13:00" }

      expect(slot_10["available"]).to be true
      expect(slot_11["available"]).to be false
      expect(slot_11["booked_by"]).to eq("Иван Иванов")
      expect(slot_12["available"]).to be false
      expect(slot_13["available"]).to be true
    end

    it "оставляет слоты доступными, если бронирование отменено (cancelled)" do
      create(
        :booking,
        user: user,
        resource: resource,
        status: "cancelled",
        booking_date: target_date,
        start_time: "14:00",
        end_time: "16:00"
      )

      get "/api/v1/resources/#{resource.slug}/availability", params: { date: target_date }
      data = JSON.parse(response.body)

      slot_14 = data["slots"].find { |s| s["time_label"] == "14:00" }
      slot_15 = data["slots"].find { |s| s["time_label"] == "15:00" }

      expect(slot_14["available"]).to be true
      expect(slot_15["available"]).to be true
    end

    it "возвращает слоты строго по заданному автором временному промежутку" do
      custom_resource = create(:resource, available_from_time: "10:00", available_to_time: "15:00")
      get "/api/v1/resources/#{custom_resource.slug}/availability", params: { date: target_date }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)
      expect(data["available_from_time"]).to eq("10:00")
      expect(data["available_to_time"]).to eq("15:00")
      expect(data["slots"].size).to eq(5)
      expect(data["slots"].first["time_label"]).to eq("10:00")
      expect(data["slots"].last["end_label"]).to eq("15:00")
    end
  end

  describe "POST /api/v1/availabilities/check" do
    it "возвращает available: true, расчет длительности и стоимости для свободного интервала" do
      post "/api/v1/availabilities/check", params: {
        resource_id: resource.id,
        booking_date: target_date,
        start_time: "10:00",
        end_time: "13:00"
      }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      expect(data["available"]).to be true
      expect(data["duration_hours"]).to eq(3)
      expect(data["total_price"]).to eq(6000)
    end

    it "возвращает available: false если интервал пересекается с существующей активной бронью" do
      create(
        :booking,
        user: user,
        resource: resource,
        status: "confirmed",
        booking_date: target_date,
        start_time: "12:00",
        end_time: "14:00"
      )

      post "/api/v1/availabilities/check", params: {
        resource_id: resource.id,
        booking_date: target_date,
        start_time: "13:00",
        end_time: "15:00"
      }

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)

      expect(data["available"]).to be false
    end
  end
end
