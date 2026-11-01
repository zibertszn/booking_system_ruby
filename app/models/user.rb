# frozen_string_literal: true

class User < ApplicationRecord
  # Модули аутентификации Devise
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :bookings, dependent: :destroy
  has_many :resources, dependent: :destroy

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
end
