# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Resources", type: :request do
  around do |example|
    orig = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    example.run
    ActionController::Base.allow_forgery_protection = orig
  end

  describe "GET /resources/new" do
    it "возвращает 200 OK и содержит элементы выбора периода ставки через кнопки" do
      get "/resources/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("rate_unit_section")
      expect(response.body).to include("rate-unit-btn")
      expect(response.body).to include("в час")
      expect(response.body).to include("в день")
      expect(response.body).to include("в месяц")
      expect(response.body).to include("в год")
      expect(response.body).not_to include('<select name="resource[rate_unit]"')
      expect(response.body).to include('<input type="hidden" name="resource[rate_unit]"')
    end

    it "не содержит пункт 'Оснащение и удобства (через запятую)'" do
      get "/resources/new"
      expect(response.body).not_to include("Оснащение и удобства (через запятую)")
    end

    it "позволяет вводить любые круглые значения ставки (например, 1400 или 1500) без ошибки шага (step)" do
      get "/resources/new"
      expect(response.body).to include('step="any"')
      expect(response.body).not_to include('step="100"')
    end

    it "содержит обновленный текст предпросмотра без примечания об обрезке" do
      get "/resources/new"
      expect(response.body).to include("Предпросмотр фотографии появится здесь после выбора файла")
      expect(response.body).not_to include("Предпросмотр фотографии появится здесь после выбора файла (масштабирование без обрезки)")
    end

    it "содержит элементы для динамического названия ресурса и управления полем вместимости" do
      get "/resources/new"
      expect(response.body).to include('id="resource_name_label"')
      expect(response.body).to include('Название помещения *')
      expect(response.body).to include('Название оборудования *')
      expect(response.body).to include('id="capacity_field_container"')
    end

    it "не содержит функционал и упоминания скейлинга при загрузке изображения" do
      get "/resources/new"
      expect(response.body).not_to include("скейлинг")
      expect(response.body).not_to include("масштабирование")
      expect(response.body).not_to include("Скейлинг")
    end
  end

  describe "Шапка сайта (навигация)" do
    it "не содержит пункты 'Помещение' и 'Оборудование' в шапке сайта, но содержит 'Мои объявления'" do
      get "/resources"
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('<a href="/resources?category=rooms"')
      expect(response.body).not_to include('<a href="/resources?category=equipment"')
      expect(response.body).to include("Каталог")
      expect(response.body).to include("Мои бронирования")
      expect(response.body).to include("Мои объявления")
      expect(response.body).to include('<a href="/my_resources"')
    end
  end

  describe "POST /resources" do
    context "для категории Помещение (rooms)" do
      it "создает помещение со ставкой в месяц" do
        post "/resources", params: {
          resource: {
            name: "Кабинет на месяц",
            category: "rooms",
            rate_unit: "month",
            hourly_rate: 75000,
            capacity: 5,
            location: "Этаж 4",
            description: "Офис в аренду на месяц"
          }
        }
        resource = Resource.find_by(name: "Кабинет на месяц")
        expect(resource).to be_present
        expect(resource.rate_unit).to eq("month")
        expect(resource.rate_unit_label).to eq("месяц")
        expect(resource.hourly_rate).to eq(75000)
        expect(response).to redirect_to(resource_path(resource.slug))
      end

      it "создает ресурс с указанным автором временным промежутком бронирования" do
        post "/resources", params: {
          resource: {
            name: "Студия с особым графиком",
            category: "rooms",
            rate_unit: "hour",
            hourly_rate: 2500,
            available_from_time: "10:00",
            available_to_time: "17:00",
            available_from_date: Date.current.to_s,
            available_to_date: (Date.current + 14.days).to_s,
            description: "Студия с графиком с 10:00 до 17:00"
          }
        }
        resource = Resource.find_by(name: "Студия с особым графиком")
        expect(resource).to be_present
        expect(resource.available_from_time).to eq("10:00")
        expect(resource.available_to_time).to eq("17:00")
        expect(resource.available_from_date).to eq(Date.current)
        expect(resource.available_to_date).to eq(Date.current + 14.days)
      end

      it "создает помещение со ставкой в день" do
        post "/resources", params: {
          resource: {
            name: "Зал на день",
            category: "rooms",
            rate_unit: "day",
            hourly_rate: 10000,
            capacity: 20,
            location: "Этаж 2",
            description: "Зал для мероприятий на полный день"
          }
        }
        resource = Resource.find_by(name: "Зал на день")
        expect(resource).to be_present
        expect(resource.rate_unit).to eq("day")
        expect(resource.rate_unit_label).to eq("день")
      end

      it "создает помещение со ставкой в год" do
        post "/resources", params: {
          resource: {
            name: "Помещение на год",
            category: "rooms",
            rate_unit: "year",
            hourly_rate: 800000,
            capacity: 15,
            location: "Корпус С",
            description: "Годовая аренда помещения"
          }
        }
        resource = Resource.find_by(name: "Помещение на год")
        expect(resource).to be_present
        expect(resource.rate_unit).to eq("year")
        expect(resource.rate_unit_label).to eq("год")
      end
    end

    context "для категории Оборудование (equipment)" do
      it "сохраняет ставку в день для оборудования и сбрасывает вместимость" do
        post "/resources", params: {
          resource: {
            name: "Камера на день",
            category: "equipment",
            rate_unit: "day",
            hourly_rate: 4500,
            location: "Цех 1",
            description: "Профессиональная камера"
          }
        }
        resource = Resource.find_by(name: "Камера на день")
        expect(resource).to be_present
        expect(resource.rate_unit).to eq("day")
        expect(resource.rate_unit_label).to eq("день")
        expect(resource.hourly_rate).to eq(4500)
        expect(resource.capacity).to be_nil
      end

      it "сохраняет ставку в месяц для оборудования" do
        post "/resources", params: {
          resource: {
            name: "Свет на месяц",
            category: "equipment",
            rate_unit: "month",
            hourly_rate: 30000,
            location: "Склад",
            description: "Комплект освещения в длительную аренду"
          }
        }
        resource = Resource.find_by(name: "Свет на месяц")
        expect(resource).to be_present
        expect(resource.rate_unit).to eq("month")
        expect(resource.rate_unit_label).to eq("месяц")
        expect(resource.capacity).to be_nil
      end
    end

    context "для категории Специалисты (specialists)" do
      it "сбрасывает rate_unit в hour и сбрасывает вместимость" do
        post "/resources", params: {
          resource: {
            name: "Звукорежиссер",
            category: "specialists",
            rate_unit: "month",
            hourly_rate: 2500,
            location: "Студия",
            description: "Штатный звукорежиссер"
          }
        }
        resource = Resource.find_by(name: "Звукорежиссер")
        expect(resource).to be_present
        expect(resource.rate_unit).to eq("hour")
        expect(resource.rate_unit_label).to eq("час")
        expect(resource.capacity).to be_nil
      end
    end
  end

  describe "GET /resources (Каталог)" do
    it "корректно отображает единицу ставки на карточке" do
      create(:resource, name: "Офис Месячный", category: "rooms", rate_unit: "month", hourly_rate: 50000)
      get "/resources"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("50,000 ₽")
      expect(response.body).to include("/ месяц")
    end
  end

  describe "Мои объявления" do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let!(:user_room) do
      create(:resource, name: "Моя переговорная", category: "rooms", user: user, hourly_rate: 2000, rate_unit: "hour")
    end
    let!(:user_equipment) do
      create(:resource, name: "Моя видеокамера", category: "equipment", user: user, hourly_rate: 5000, rate_unit: "day")
    end
    let!(:other_resource) do
      create(:resource, name: "Чужое объявление", category: "rooms", user: other_user)
    end

    describe "GET /my_resources" do
      context "когда пользователь не авторизован" do
        it "перенаправляет на страницу входа" do
          get "/my_resources"
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "когда пользователь авторизован" do
        before { sign_in user }

        it "возвращает 200 OK и отображает только объявления текущего пользователя" do
          get "/my_resources"
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Мои объявления")
          expect(response.body).to include("Моя переговорная")
          expect(response.body).to include("Моя видеокамера")
          expect(response.body).not_to include("Чужое объявление")
          expect(response.body).to include("Редактировать")
          expect(response.body).to include("Удалить")
        end

        it "корректно фильтрует по категории" do
          get "/my_resources", params: { category: "equipment" }
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Моя видеокамера")
          expect(response.body).not_to include("Моя переговорная")
        end
      end
    end

    describe "GET /resources/:id/edit" do
      context "когда пользователь не авторизован" do
        it "перенаправляет на страницу входа" do
          get edit_resource_path(user_room.slug)
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "когда пользователь авторизован как владелец" do
        before { sign_in user }

        it "открывает форму редактирования объявления с предзаполненными данными" do
          get edit_resource_path(user_room.slug)
          expect(response).to have_http_status(:ok)
          expect(response.body).to include("Редактировать объявление")
          expect(response.body).to include("Моя переговорная")
          expect(response.body).to include('value="2000"')
          expect(response.body).to include("Сохранить изменения")
        end
      end

      context "когда пользователь пытается редактировать чужое объявление" do
        before { sign_in user }

        it "перенаправляет на мои объявления с сообщением об ошибке" do
          get edit_resource_path(other_resource.slug)
          expect(response).to redirect_to(my_resources_path)
          follow_redirect!
          expect(response.body).to include("Объявление не найдено или у вас нет прав на его изменение")
        end
      end
    end

    describe "PATCH /resources/:id" do
      before { sign_in user }

      it "успешно обновляет объявление и перенаправляет в мои объявления" do
        patch resource_path(user_room.slug), params: {
          resource: {
            name: "Обновленная переговорная",
            category: "rooms",
            hourly_rate: 3500,
            rate_unit: "day",
            capacity: 12,
            location: "Корпус C, 4 этаж",
            description: "Новое описание помещения"
          }
        }
        expect(response).to redirect_to(my_resources_path)
        follow_redirect!
        expect(response.body).to include("Объявление «Обновленная переговорная» успешно обновлено")

        user_room.reload
        expect(user_room.name).to eq("Обновленная переговорная")
        expect(user_room.hourly_rate).to eq(3500)
        expect(user_room.rate_unit).to eq("day")
        expect(user_room.capacity).to eq(12)
        expect(user_room.location).to eq("Корпус C, 4 этаж")
        expect(user_room.description).to eq("Новое описание помещения")
      end

      it "запрещает обновлять чужое объявление" do
        patch resource_path(other_resource.slug), params: {
          resource: { name: "Попытка взлома" }
        }
        expect(response).to redirect_to(my_resources_path)
        other_resource.reload
        expect(other_resource.name).to eq("Чужое объявление")
      end
    end

    describe "DELETE /resources/:id" do
      before { sign_in user }

      it "успешно удаляет объявление и перенаправляет в мои объявления" do
        expect {
          delete resource_path(user_room.slug)
        }.to change(Resource, :count).by(-1)

        expect(response).to redirect_to(my_resources_path)
        follow_redirect!
        expect(response.body).to include("Объявление «Моя переговорная» успешно удалено")
        expect(Resource.find_by(id: user_room.id)).to be_nil
      end

      it "запрещает удалять чужое объявление" do
        expect {
          delete resource_path(other_resource.slug)
        }.not_to change(Resource, :count)

        expect(response).to redirect_to(my_resources_path)
        expect(Resource.find_by(id: other_resource.id)).to be_present
      end
    end

    describe "POST /resources/:id/update_image" do
      context "когда пользователь не авторизован" do
        it "перенаправляет на страницу входа" do
          post update_image_resource_path(user_room.slug), params: { image_url: "https://example.com/new.jpg" }
          expect(response).to redirect_to(new_user_session_path)
        end
      end

      context "когда пользователь авторизован как владелец" do
        before { sign_in user }

        it "успешно обновляет фото объявления" do
          post update_image_resource_path(user_room.slug), params: { image_url: "https://example.com/my-room.jpg" }
          expect(response).to redirect_to(resource_path(user_room.slug))
          user_room.reload
          expect(user_room.image_url).to eq("https://example.com/my-room.jpg")
        end

        it "успешно обновляет фото через JSON API" do
          post update_image_resource_path(user_room.slug, format: :json), params: { image_url: "https://example.com/my-room.jpg" }
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          expect(data["image_url"]).to eq("https://example.com/my-room.jpg")
        end
      end

      context "когда пользователь пытается обновить фото чужого объявления" do
        before { sign_in user }

        it "запрещает изменение через HTML" do
          post update_image_resource_path(other_resource.slug), params: { image_url: "https://example.com/hacked.jpg" }
          expect(response).to redirect_to(my_resources_path)
          other_resource.reload
          expect(other_resource.image_url).not_to eq("https://example.com/hacked.jpg")
        end

        it "возвращает 403 Forbidden через JSON" do
          post update_image_resource_path(other_resource.slug, format: :json), params: { image_url: "https://example.com/hacked.jpg" }
          expect(response).to have_http_status(:forbidden)
          other_resource.reload
          expect(other_resource.image_url).not_to eq("https://example.com/hacked.jpg")
        end
      end
    end

    describe "GET /resources/:id (отображение виджета загрузки фото)" do
      it "не отображает виджет загрузки фото для неавторизованного пользователя" do
        get resource_path(user_room.slug)
        expect(response.body).not_to include('id="vue-resource-image-uploader"')
      end

      it "не отображает виджет загрузки фото для чужого объявления" do
        sign_in user
        get resource_path(other_resource.slug)
        expect(response.body).not_to include('id="vue-resource-image-uploader"')
      end

      it "отображает виджет загрузки фото для автора объявления" do
        sign_in user
        get resource_path(user_room.slug)
        expect(response.body).to include('id="vue-resource-image-uploader"')
      end
    end
  end
end
