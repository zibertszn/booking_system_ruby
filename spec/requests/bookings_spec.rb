# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Bookings Integration", type: :request do
  around do |example|
    orig = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    example.run
    ActionController::Base.allow_forgery_protection = orig
  end

  let(:user) { create(:user, name: "Тестовый Арендатор", email: "renter@example.com") }
  let(:other_user) { create(:user, name: "Другой Арендатор", email: "other@example.com") }
  let(:resource) { create(:resource, name: "Переговорная Тест", hourly_rate: 1500) }

  describe "GET /bookings (Личный кабинет: Мои бронирования)" do
    context "когда пользователь не авторизован" do
      it "перенаправляет на страницу авторизации" do
        get "/bookings"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "когда пользователь авторизован" do
      before { sign_in user }

      it "возвращает 200 OK и отображает список бронирований текущего пользователя" do
        booking = create(:booking, user: user, resource: resource, booking_date: Date.current + 2, start_time: "10:00", end_time: "12:00")
        other_booking = create(:booking, user: other_user, resource: resource, booking_date: Date.current + 3, start_time: "14:00", end_time: "16:00")

        get "/bookings"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Мои бронирования")
        expect(response.body).to include(resource.name)
        expect(response.body).to include("10:00")
        expect(response.body).to include("12:00")
        expect(response.body).not_to include("other@example.com")
      end

      it "корректно фильтрует по статусам confirmed и cancelled" do
        confirmed_booking = create(:booking, user: user, resource: resource, status: "confirmed", booking_date: Date.current + 1, start_time: "10:00", end_time: "11:00")
        cancelled_booking = create(:booking, user: user, resource: resource, status: "cancelled", booking_date: Date.current + 2, start_time: "12:00", end_time: "13:00")

        get "/bookings", params: { status: "confirmed" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("10:00–11:00")
        expect(response.body).not_to include("12:00–13:00")

        get "/bookings", params: { status: "cancelled" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("12:00–13:00")
        expect(response.body).not_to include("10:00–11:00")
      end

      it "отображает сводную статистику пользователя (активные брони, часы, сумма)" do
        create(:booking, user: user, resource: resource, duration_hours: 3, total_price: 4500, status: "confirmed", booking_date: Date.current + 1, start_time: "10:00", end_time: "13:00")

        get "/bookings"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("4,500 ₽")
        expect(response.body).to include("3 ч.")
      end
    end
  end

  describe "GET /bookings/:id (Просмотр бронирования)" do
    let(:booking) { create(:booking, user: user, resource: resource) }

    context "когда пользователь авторизован как владелец брони" do
      before { sign_in user }

      it "возвращает 200 OK со сведениями о брони" do
        get "/bookings/#{booking.id}"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(resource.name)
        expect(response.body).to include(booking.contact_name)
      end
    end

    context "когда чужой пользователь пытается открыть бронирование" do
      before { sign_in other_user }

      it "возвращает 404 Not Found" do
        get "/bookings/#{booking.id}"
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "POST /bookings (Создание бронирования)" do
    let(:target_date) { (Date.current + 1).to_s }
    let(:valid_params) do
      {
        booking: {
          resource_id: resource.id,
          booking_date: target_date,
          start_time: "14:00",
          end_time: "16:00",
          contact_name: "Тестовый Арендатор",
          contact_email: "renter@example.com",
          contact_phone: "+7 (999) 555-44-33",
          purpose: "Презентация проекта"
        }
      }
    end

    context "когда пользователь не авторизован" do
      it "перенаправляет на страницу входа" do
        post "/bookings", params: valid_params
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "когда пользователь авторизован" do
      before { sign_in user }

      it "успешно создает бронирование через HTML-форму и перенаправляет на страницу брони" do
        expect {
          post "/bookings", params: valid_params
        }.to change(Booking, :count).by(1)

        created_booking = Booking.last
        expect(created_booking.user).to eq(user)
        expect(created_booking.resource).to eq(resource)
        expect(created_booking.duration_hours).to eq(2)
        expect(created_booking.total_price).to eq(3000)
        expect(created_booking.status).to eq("confirmed")

        expect(response).to redirect_to(booking_path(created_booking))
        follow_redirect!
        expect(response.body).to include("Бронирование успешно оформлено")
      end

      it "успешно создает бронирование через JSON API (виджет Vue.js)" do
        post "/bookings", params: valid_params, as: :json
        expect(response).to have_http_status(:created)

        data = JSON.parse(response.body)
        expect(data["booking"]["status"]).to eq("confirmed")
        expect(data["redirect_url"]).to be_present
      end

      it "возвращает ошибку 422 при невалидных данных (например, пустое имя контакта)" do
        invalid_params = valid_params.deep_merge(booking: { contact_name: "" })

        post "/bookings", params: invalid_params, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        data = JSON.parse(response.body)
        expect(data["errors"]).to be_present
      end

      it "предотвращает овербукинг (двойное бронирование того же слота)" do
        # Первое бронирование 14:00 - 16:00
        post "/bookings", params: valid_params, as: :json
        expect(response).to have_http_status(:created)

        # Вторая попытка занять пересекающийся слот 15:00 - 17:00
        overlapping_params = valid_params.deep_merge(booking: { start_time: "15:00", end_time: "17:00" })
        post "/bookings", params: overlapping_params, as: :json
        expect(response).to have_http_status(:conflict).or have_http_status(:unprocessable_entity)

        data = JSON.parse(response.body)
        expect(data["errors"].to_s).to match(/занят|пересека/i)
      end

      it "запрещает пользователю бронировать собственное объявление через HTML" do
        own_resource = create(:resource, user: user, hourly_rate: 1500)
        own_params = valid_params.deep_merge(booking: { resource_id: own_resource.id })

        expect {
          post "/bookings", params: own_params
        }.not_to change(Booking, :count)

        expect(response).to redirect_to(resource_path(own_resource.slug))
        follow_redirect!
        expect(response.body).to include("Вы не можете забронировать собственное объявление")
      end

      it "запрещает пользователю бронировать собственное объявление через JSON" do
        own_resource = create(:resource, user: user, hourly_rate: 1500)
        own_params = valid_params.deep_merge(booking: { resource_id: own_resource.id })

        expect {
          post "/bookings", params: own_params, as: :json
        }.not_to change(Booking, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        data = JSON.parse(response.body)
        expect(data["errors"]).to include("Вы не можете забронировать собственное объявление.")
      end
    end
  end

  describe "PATCH /bookings/:id/cancel (Отмена бронирования)" do
    let!(:booking) do
      create(:booking, user: user, resource: resource, status: "confirmed", booking_date: Date.current + 2, start_time: "11:00", end_time: "13:00")
    end

    context "когда бронь отменяет её владелец" do
      before { sign_in user }

      it "отменяет бронь через HTML и перенаправляет с уведомлением" do
        patch "/bookings/#{booking.id}/cancel"
        expect(response).to redirect_to(bookings_path)
        follow_redirect!
        expect(response.body).to include("отменено. Слот освобожден")

        booking.reload
        expect(booking.status).to eq("cancelled")
      end

      it "отменяет бронь через JSON API" do
        patch "/bookings/#{booking.id}/cancel", as: :json
        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data["status"]).to eq("cancelled")

        booking.reload
        expect(booking.status).to eq("cancelled")
      end
    end

    context "когда чужой пользователь пытается отменить бронь" do
      before { sign_in other_user }

      it "запрещает отмену чужого бронирования (404 Not Found)" do
        patch "/bookings/#{booking.id}/cancel"
        expect(response).to have_http_status(:not_found)

        booking.reload
        expect(booking.status).to eq("confirmed")
      end
    end
  end
end
