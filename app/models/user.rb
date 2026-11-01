# frozen_string_literal: true

class User < ApplicationRecord
  # Модули аутентификации Devise
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :bookings, dependent: :destroy
  has_many :resources, dependent: :destroy
  has_many :chat_messages, dependent: :destroy
  has_many :customer_chat_rooms, class_name: "ChatRoom", foreign_key: :customer_id, dependent: :destroy
  has_many :owner_chat_rooms, class_name: "ChatRoom", foreign_key: :owner_id, dependent: :destroy

  def chat_rooms
    ChatRoom.for_user(self)
  end

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
end
