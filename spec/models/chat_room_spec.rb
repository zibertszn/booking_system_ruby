# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChatRoom, type: :model do
  describe "ассоциации" do
    it { is_expected.to belong_to(:customer).class_name("User") }
    it { is_expected.to belong_to(:owner).class_name("User") }
    it { is_expected.to belong_to(:resource).optional }
    it { is_expected.to belong_to(:booking).optional }
    it { is_expected.to have_many(:chat_messages).dependent(:destroy) }
  end

  describe "валидации" do
    it { is_expected.to validate_presence_of(:title) }

    it "запрещает создавать чат заказчика с самим собой" do
      user = create(:user)
      room = build(:chat_room, customer: user, owner: user)
      expect(room).not_to be_valid
      expect(room.errors[:customer]).to be_present
    end
  end

  describe "методы ролей и собеседника" do
    let(:customer) { create(:user, name: "Иван Заказчик") }
    let(:owner) { create(:user, name: "Петр Владелец") }
    let(:room) { create(:chat_room, customer: customer, owner: owner) }

    it "корректно определяет участников" do
      expect(room.participant?(customer)).to be true
      expect(room.participant?(owner)).to be true
      expect(room.participant?(create(:user))).to be false
      expect(room.participant?(nil)).to be false
    end

    it "возвращает собеседника для текущего пользователя" do
      expect(room.interlocutor_for(customer)).to eq(owner)
      expect(room.interlocutor_for(owner)).to eq(customer)
    end

    it "возвращает правильные роли" do
      expect(room.role_for(customer)).to eq("Заказчик")
      expect(room.role_for(owner)).to eq("Владелец объявления")
      expect(room.other_role_for(customer)).to eq("Владелец объявления")
      expect(room.other_role_for(owner)).to eq("Заказчик")
    end
  end

  describe ".find_or_create_for_resource" do
    let(:owner) { create(:user, name: "Автор объявления") }
    let(:customer) { create(:user, name: "Покупатель") }
    let(:resource) { create(:resource, user: owner, name: "Проектор") }

    it "создает диалог 1 на 1 между заказчиком и владельцем объявления" do
      room = ChatRoom.find_or_create_for_resource(customer: customer, resource: resource)
      expect(room).to be_persisted
      expect(room.customer).to eq(customer)
      expect(room.owner).to eq(owner)
      expect(room.resource).to eq(resource)
      expect(room.title).to include(resource.name)
    end

    it "не создает дубликатов при повторном вызове" do
      room1 = ChatRoom.find_or_create_for_resource(customer: customer, resource: resource)
      room2 = ChatRoom.find_or_create_for_resource(customer: customer, resource: resource)
      expect(room1.id).to eq(room2.id)
    end

    it "вызывает ошибку при попытке создать чат с самим собой" do
      expect {
        ChatRoom.find_or_create_for_resource(customer: owner, resource: resource)
      }.to raise_error(ArgumentError, /Нельзя начать чат с самим собой/)
    end
  end

  describe ".find_or_create_for_booking" do
    let(:customer) { create(:user) }
    let(:owner) { create(:user) }
    let(:resource) { create(:resource, user: owner, name: "Кабинет 1") }
    let(:booking) { create(:booking, user: customer, resource: resource) }

    it "находит или создает комнату чата 1 на 1 для конкретного бронирования" do
      room = ChatRoom.find_or_create_for_booking(booking)
      expect(room).to be_persisted
      expect(room.customer).to eq(customer)
      expect(room.owner).to eq(owner)
      expect(room.booking).to eq(booking)
      expect(room.title).to include("##{booking.id}")
    end
  end
end
