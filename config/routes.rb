Rails.application.routes.draw do
  # Аутентификация пользователей через Devise
  devise_for :users

  # Главная страница — каталог ресурсов
  root "resources#index"

  # Мои объявления пользователя
  get "/my_resources", to: "resources#my", as: :my_resources
  get "/my/resources", to: "resources#my"

  # Ресурсы для бронирования (просмотр, создание, редактирование и удаление)
  resources :resources, only: [:index, :show, :new, :create, :edit, :update, :destroy] do
    member do
      post :update_image
      patch :update_image
    end
  end

  # Управление бронированиями и Личный кабинет
  resources :bookings, only: [:index, :show, :create] do
    member do
      patch :cancel
      post :cancel
    end
  end

  # Легковесные JSON-эндпоинты специально для реактивных виджетов Vue.js
  namespace :api do
    namespace :v1 do
      resources :resources, only: [] do
        member do
          get :availability
        end
      end
      post "availabilities/check", to: "availabilities#check"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
