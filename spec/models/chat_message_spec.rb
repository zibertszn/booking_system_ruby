# frozen_string_literal: true

require "rails_helper"

RSpec.describe ChatMessage, type: :model do
  describe "ассоциации" do
    it { is_expected.to belong_to(:chat_room) }
    it { is_expected.to belong_to(:user) }
  end

  describe "валидации" do
    it { is_expected.to validate_presence_of(:content) }
  end

  describe "вебсокет-трансляция (Turbo Streams broadcast)" do
    let(:user) { create(:user) }
    let(:room) { create(:chat_room) }

    it "вызывает broadcast_append_to при сохранении нового сообщения" do
      message = build(:chat_message, user: user, chat_room: room, content: "Тестовое живое сообщение")
      expect(message).to receive(:broadcast_append_to).with(
        room,
        target: "chat_messages_list_#{room.id}",
        partial: "chat_messages/message",
        locals: { message: message }
      )
      message.save!
    end
  end
end
