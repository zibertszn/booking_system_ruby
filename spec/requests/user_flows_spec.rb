# frozen_string_literal: true

require "rails_helper"

RSpec.describe "End-to-End User Journeys (Интеграционные сценарии)", type: :request do
  around do |example|
    orig = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    example.run
    ActionController::Base.allow_forgery_protection = orig
  end

  let(:renter) { create(:user, name: "Иван Арендатор", email: "ivan.renter@example.com") }
  let(:owner)  { create(:user, name: "Петр Владелец", email: "petr.owner@example.com") }
  let(:target_date) { (Date.current + 5).to_s }

  describe "Сценарий 1: Полный цикл бронирования и отмены слота" do
    let!(:resource) do
      create(
        :resource,
        name: "Конференц-зал Панорама",
        slug: "res-panorama",
        category: "rooms",
        hourly_rate: 3000,
        rate_unit: "hour",
        user: owner
      )
    end

    it "проводит пользователя от просмотра каталога до успешного бронирования и последующей отмены" do
      # 1. Гость заходит в каталог
      get "/resources"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Конференц-зал Панорама")
      expect(response.body).to include("3,000 ₽")

      # 2. Открывает карточку ресурса
      get "/resources/res-panorama"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Конференц-зал Панорама")

      # 3. Виджет Vue проверяет доступность слотов на дату
      get "/api/v1/resources/res-panorama/availability", params: { date: target_date }
      expect(response).to have_http_status(:ok)
      slots_data = JSON.parse(response.body)["slots"]
      slot_14 = slots_data.find { |s| s["time_label"] == "14:00" }
      expect(slot_14["available"]).to be true

      # 4. Проверяет расчет диапазона 14:00 - 17:00 (3 часа)
      post "/api/v1/availabilities/check", params: {
        resource_id: resource.id,
        booking_date: target_date,
        start_time: "14:00",
        end_time: "17:00"
      }
      expect(response).to have_http_status(:ok)
      check_data = JSON.parse(response.body)
      expect(check_data["available"]).to be true
      expect(check_data["duration_hours"]).to eq(3)
      expect(check_data["total_price"]).to eq(9000)

      # 5. Пользователь авторизуется
      sign_in renter

      # 6. Оформляет бронирование через POST /bookings
      post "/bookings", params: {
        booking: {
          resource_id: resource.id,
          booking_date: target_date,
          start_time: "14:00",
          end_time: "17:00",
          contact_name: renter.name,
          contact_email: renter.email,
          contact_phone: "+7 (999) 000-11-22",
          purpose: "Проведение дизайн-сессии"
        }
      }
      booking = Booking.last
      expect(booking.user).to eq(renter)
      expect(booking.resource).to eq(resource)
      expect(booking.total_price).to eq(9000)
      expect(booking.status).to eq("confirmed")
      expect(response).to redirect_to(booking_path(booking))

      # 7. Открывает страницу подтверждения бронирования
      follow_redirect!
      expect(response.body).to include("Бронирование успешно оформлено")
      expect(response.body).to include("Конференц-зал Панорама")
      expect(response.body).to include("9,000 ₽")

      # 8. Заходит в «Мои бронирования»
      get "/bookings"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Конференц-зал Панорама")
      expect(response.body).to include("14:00–17:00")
      expect(response.body).to include("Подтверждено")

      # 9. Проверяет, что занятые часы теперь недоступны в расписании
      get "/api/v1/resources/res-panorama/availability", params: { date: target_date }
      updated_slots = JSON.parse(response.body)["slots"]
      expect(updated_slots.find { |s| s["time_label"] == "14:00" }["available"]).to be false
      expect(updated_slots.find { |s| s["time_label"] == "15:00" }["available"]).to be false
      expect(updated_slots.find { |s| s["time_label"] == "16:00" }["available"]).to be false
      expect(updated_slots.find { |s| s["time_label"] == "17:00" }["available"]).to be true

      # 10. Отменяет бронирование
      patch "/bookings/#{booking.id}/cancel"
      expect(response).to redirect_to(bookings_path)
      follow_redirect!
      expect(response.body).to include("отменено. Слот освобожден")
      expect(booking.reload.status).to eq("cancelled")

      # 11. Проверяет, что слот снова свободен для других пользователей
      get "/api/v1/resources/res-panorama/availability", params: { date: target_date }
      freed_slots = JSON.parse(response.body)["slots"]
      expect(freed_slots.find { |s| s["time_label"] == "14:00" }["available"]).to be true
      expect(freed_slots.find { |s| s["time_label"] == "15:00" }["available"]).to be true
      expect(freed_slots.find { |s| s["time_label"] == "16:00" }["available"]).to be true
    end
  end

  describe "Сценарий 2: Полный цикл публикации, редактирования и удаления объявления" do
    before { sign_in owner }

    it "позволяет пользователю создать объявление, изменить его условия и удалить" do
      # 1. Пользователь переходит на страницу добавления ресурса
      get "/resources/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Добавить новый ресурс для бронирования")
      expect(response.body).to include("Название помещения *")

      # 2. Создает объявление с месячной ставкой
      post "/resources", params: {
        resource: {
          name: "Коворкинг Офис 105",
          category: "rooms",
          hourly_rate: 65000,
          rate_unit: "month",
          capacity: 8,
          location: "Башня Восток, 10 этаж",
          description: "Светлый смарт-офис с панорамным видом",
          image_url: "/images/room_alpha.svg"
        }
      }
      new_resource = Resource.find_by(name: "Коворкинг Офис 105")
      expect(new_resource).to be_present
      expect(new_resource.user).to eq(owner)
      expect(new_resource.rate_unit).to eq("month")
      expect(new_resource.hourly_rate).to eq(65000)
      expect(response).to redirect_to(resource_path(new_resource.slug))

      # 3. Видит объявление в «Моих объявлениях»
      get "/my_resources"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Коворкинг Офис 105")
      expect(response.body).to include("65,000 ₽")
      expect(response.body).to include("/ месяц")
      expect(response.body).to include("Редактировать")
      expect(response.body).to include("Удалить")

      # 4. Проверяет отображение карточки в общем каталоге
      get "/resources"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Коворкинг Офис 105")
      expect(response.body).to include("65,000 ₽")
      expect(response.body).to include("/ месяц")

      # 5. Переходит к редактированию объявления
      get edit_resource_path(new_resource.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Редактировать объявление")
      expect(response.body).to include('value="65000"')

      # 6. Обновляет ставку и описание
      patch resource_path(new_resource.slug), params: {
        resource: {
          name: "Коворкинг Офис 105 Люкс",
          category: "rooms",
          hourly_rate: 80000,
          rate_unit: "month",
          capacity: 10,
          location: "Башня Восток, 10 этаж, блок А",
          description: "Обновленный офис представительского класса"
        }
      }
      expect(response).to redirect_to(my_resources_path)
      follow_redirect!
      expect(response.body).to include("успешно обновлено")

      new_resource.reload
      expect(new_resource.name).to eq("Коворкинг Офис 105 Люкс")
      expect(new_resource.hourly_rate).to eq(80000)
      expect(new_resource.capacity).to eq(10)

      # 7. Удаляет объявление
      expect {
        delete resource_path(new_resource.slug)
      }.to change(Resource, :count).by(-1)

      expect(response).to redirect_to(my_resources_path)
      follow_redirect!
      expect(response.body).to include("успешно удалено")

      # 8. Проверяет отсутствие в общем каталоге
      get "/resources"
      expect(response.body).not_to include("Коворкинг Офис 105 Люкс")
    end
  end

  describe "Сценарий 3: Защита от конкурентного овербукинга" do
    let(:user_a) { create(:user, email: "user_a@example.com") }
    let(:user_b) { create(:user, email: "user_b@example.com") }
    let(:resource) { create(:resource, hourly_rate: 1000) }

    it "гарантирует невозможность двойного бронирования одного и того же слота" do
      # Пользователь А бронирует 10:00 - 12:00
      sign_in user_a
      post "/bookings", params: {
        booking: {
          resource_id: resource.id,
          booking_date: target_date,
          start_time: "10:00",
          end_time: "12:00",
          contact_name: "Пользователь А",
          contact_email: "user_a@example.com"
        }
      }, as: :json
      expect(response).to have_http_status(:created)

      # Пользователь Б пытается занять пересекающийся интервал 11:00 - 13:00
      sign_in user_b
      post "/bookings", params: {
        booking: {
          resource_id: resource.id,
          booking_date: target_date,
          start_time: "11:00",
          end_time: "13:00",
          contact_name: "Пользователь Б",
          contact_email: "user_b@example.com"
        }
      }, as: :json

      expect(response).to have_http_status(:conflict).or have_http_status(:unprocessable_entity)
      expect(Booking.where(resource: resource, status: "confirmed").count).to eq(1)

      # Пользователь А отменяет бронирование
      sign_in user_a
      booking_a = Booking.find_by(contact_email: "user_a@example.com")
      patch "/bookings/#{booking_a.id}/cancel", as: :json
      expect(response).to have_http_status(:ok)

      # Теперь пользователь Б успешно занимает этот слот
      sign_in user_b
      post "/bookings", params: {
        booking: {
          resource_id: resource.id,
          booking_date: target_date,
          start_time: "11:00",
          end_time: "13:00",
          contact_name: "Пользователь Б",
          contact_email: "user_b@example.com"
        }
      }, as: :json
      expect(response).to have_http_status(:created)
      expect(Booking.where(resource: resource, status: "confirmed").count).to eq(1)
      expect(Booking.where(resource: resource, status: "confirmed").first.user).to eq(user_b)
    end
  end

  describe "Сценарий 4: Безопасность и изоляция данных между пользователями" do
    let(:user_1) { create(:user, email: "user1@example.com") }
    let(:user_2) { create(:user, email: "user2@example.com") }
    let(:resource_1) { create(:resource, user: user_1, name: "Ресурс Первого") }
    let(:resource_third) { create(:resource, name: "Сторонний ресурс") }
    let(:booking_1)  { create(:booking, user: user_1, resource: resource_third) }

    it "надежно изолирует данные и запрещает несанкционированные действия" do
      # 1. Неавторизованный гость не может зайти в защищенные разделы
      get "/my_resources"
      expect(response).to redirect_to(new_user_session_path)

      get "/bookings"
      expect(response).to redirect_to(new_user_session_path)

      get edit_resource_path(resource_1.slug)
      expect(response).to redirect_to(new_user_session_path)

      # 2. Пользователь 2 входит в систему
      sign_in user_2

      # 2.1 Не видит чужие объявления в «Моих объявлениях»
      get "/my_resources"
      expect(response.body).not_to include("Ресурс Первого")

      # 2.2 Не может редактировать чужое объявление
      get edit_resource_path(resource_1.slug)
      expect(response).to redirect_to(my_resources_path)

      patch resource_path(resource_1.slug), params: { resource: { name: "Взлом" } }
      expect(response).to redirect_to(my_resources_path)
      expect(resource_1.reload.name).to eq("Ресурс Первого")

      # 2.3 Не может изменить фото чужого объявления
      post update_image_resource_path(resource_1.slug, format: :json), params: { image_url: "https://evil.com/hack.jpg" }
      expect(response).to have_http_status(:forbidden)
      expect(resource_1.reload.image_url).not_to eq("https://evil.com/hack.jpg")

      # 2.4 Не может удалить чужое объявление
      delete resource_path(resource_1.slug)
      expect(response).to redirect_to(my_resources_path)
      expect(Resource.find_by(id: resource_1.id)).to be_present

      # 2.5 Не может просмотреть или отменить чужое бронирование
      get "/bookings/#{booking_1.id}"
      expect(response).to have_http_status(:not_found)

      patch "/bookings/#{booking_1.id}/cancel"
      expect(response).to have_http_status(:not_found)
      expect(booking_1.reload.status).to eq("confirmed")

      # 2.6 Пользователь не может забронировать собственное объявление
      sign_in user_1
      post "/bookings", params: {
        booking: {
          resource_id: resource_1.id,
          booking_date: (Date.current + 2).to_s,
          start_time: "10:00",
          end_time: "12:00",
          contact_name: user_1.name,
          contact_email: user_1.email
        }
      }
      expect(response).to redirect_to(resource_path(resource_1.slug))
      follow_redirect!
      expect(response.body).to include("Вы не можете забронировать собственное объявление")
    end
  end
end
