# frozen_string_literal: true

require "rails_helper"

RSpec.describe "1-on-1 Live Chat Integration (WebSockets + Turbo Streams)", type: :request do
  around do |example|
    orig = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    example.run
    ActionController::Base.allow_forgery_protection = orig
  end

  let(:customer) { create(:user, name: "Алексей Заказчик", email: "customer@example.com") }
  let(:owner) { create(:user, name: "Мария Владелец", email: "owner@example.com") }
  let(:third_party) { create(:user, name: "Иван Посторонний", email: "third@example.com") }
  let(:resource) { create(:resource, user: owner, name: "Переговорная Альфа") }
  let(:chat_room) { create(:chat_room, customer: customer, owner: owner, resource: resource) }

  describe "GET /chat" do
    context "когда пользователь не авторизован" do
      it "перенаправляет на страницу входа" do
        get "/chat"
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "когда у пользователя нет диалогов" do
      before { sign_in customer }

      it "отображает страницу со списком диалогов и приветственным состоянием" do
        get "/chat"
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("У вас пока нет активных диалогов 1 на 1")
      end
    end

    context "когда у пользователя есть активные диалоги 1 на 1" do
      before do
        chat_room # создаем комнату
        sign_in customer
      end

      it "перенаправляет на первый активный диалог" do
        get "/chat"
        expect(response).to redirect_to(chat_room_path(chat_room))
      end
    end
  end

  describe "GET /chat_rooms/:id" do
    before { create(:chat_message, chat_room: chat_room, user: owner, content: "Здравствуйте! Чем могу помочь?") }

    context "для участника диалога (заказчик)" do
      before { sign_in customer }

      it "возвращает 200 OK, содержит подписку на сокет turbo_stream_from, Turbo Frames и карточку объявления" do
        get chat_room_path(chat_room)
        expect(response).to have_http_status(:ok)

        # Подписка на WebSockets через Active Cable Turbo Streams
        expect(response.body).to include("turbo-cable-stream-source")

        # Turbo Frame для изолированного обновления формы и сообщений
        expect(response.body).to include('id="chat_room_frame"')
        expect(response.body).to include("new_chat_message_form_#{chat_room.id}")

        # Информация о собеседнике и карточке объявления
        expect(response.body).to include("Мария Владелец")
        expect(response.body).to include("Владелец объявления")
        expect(response.body).to include("Переговорная Альфа")
        expect(response.body).to include("Здравствуйте! Чем могу помочь?")
      end
    end

    context "для участника диалога (владелец объявления)" do
      before { sign_in owner }

      it "возвращает 200 OK и отображает заказчика" do
        get chat_room_path(chat_room)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Алексей Заказчик")
        expect(response.body).to include("Заказчик")
      end
    end

    context "для постороннего пользователя" do
      before { sign_in third_party }

      it "запрещает доступ и перенаправляет с предупреждением" do
        get chat_room_path(chat_room)
        expect(response).to redirect_to(chat_rooms_path)
        follow_redirect!
        expect(response.body).to include("У вас нет доступа к этому диалогу. Это приватный чат 1 на 1.")
      end
    end
  end

  describe "POST /chat_rooms/:chat_room_id/chat_messages" do
    context "когда сообщение отправляет участник диалога" do
      before { sign_in customer }

      it "успешно отправляет сообщение через Turbo Streams и очищает форму" do
        expect {
          post chat_room_chat_messages_path(chat_room),
               params: { chat_message: { content: "Здравствуйте, объявление еще актуально?" } },
               as: :turbo_stream
        }.to change(ChatMessage, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("<turbo-stream")
        expect(response.body).to include("action=\"update\"")
        expect(response.body).to include("target=\"new_chat_message_form_#{chat_room.id}\"")

        last_message = ChatMessage.last
        expect(last_message.content).to eq("Здравствуйте, объявление еще актуально?")
        expect(last_message.user).to eq(customer)
        expect(last_message.chat_room).to eq(chat_room)
      end

      it "возвращает ошибку валидации при отправке пустого сообщения" do
        expect {
          post chat_room_chat_messages_path(chat_room),
               params: { chat_message: { content: "" } },
               as: :turbo_stream
        }.not_to change(ChatMessage, :count)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("<turbo-stream")
        expect(response.body).to include("не может быть пустым")
      end
    end

    context "когда сообщение пытается отправить посторонний пользователь" do
      before { sign_in third_party }

      it "блокирует отправку со статусом 403 Forbidden" do
        expect {
          post chat_room_chat_messages_path(chat_room),
               params: { chat_message: { content: "Попытка спама" } },
               as: :turbo_stream
        }.not_to change(ChatMessage, :count)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST /chat_rooms (создание диалога 1 на 1)" do
    describe "со страницы объявления (resource_id)" do
      context "когда заказчик начинает диалог с владельцем" do
        before { sign_in customer }

        it "создает приватный диалог 1 на 1 и перенаправляет в него" do
          expect {
            post chat_rooms_path, params: { resource_id: resource.id }
          }.to change(ChatRoom, :count).by(1)

          room = ChatRoom.last
          expect(room.customer).to eq(customer)
          expect(room.owner).to eq(owner)
          expect(room.resource).to eq(resource)
          expect(response).to redirect_to(chat_room_path(room))
        end
      end

      context "когда автор пытается начать диалог со своим же объявлением" do
        before { sign_in owner }

        it "запрещает создание диалога и выводит предупреждение" do
          expect {
            post chat_rooms_path, params: { resource_id: resource.id }
          }.not_to change(ChatRoom, :count)

          expect(response).to redirect_to(resource_path(resource.slug))
          follow_redirect!
          expect(response.body).to include("Вы не можете начать чат со своим собственным объявлением")
        end
      end
    end

    describe "со страницы бронирования (booking_id)" do
      let(:booking) { create(:booking, user: customer, resource: resource) }

      context "когда заказчик бронирования открывает чат" do
        before { sign_in customer }

        it "создает диалог 1 на 1 по бронированию" do
          post chat_rooms_path, params: { booking_id: booking.id }

          room = ChatRoom.find_by(booking_id: booking.id)
          expect(room).to be_present
          expect(room.customer).to eq(customer)
          expect(room.owner).to eq(owner)
          expect(response).to redirect_to(chat_room_path(room))
        end
      end

      context "когда посторонний пытается открыть чат по чужому бронированию" do
        before { sign_in third_party }

        it "отклоняет запрос" do
          post chat_rooms_path, params: { booking_id: booking.id }
          expect(response).to redirect_to(bookings_path)
        end
      end
    end
  end
end
