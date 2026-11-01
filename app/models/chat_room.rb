# frozen_string_literal: true

class ChatRoom < ApplicationRecord
  belongs_to :customer, class_name: "User"
  belongs_to :owner, class_name: "User"
  belongs_to :resource, optional: true
  belongs_to :booking, optional: true

  has_many :chat_messages, -> { order(created_at: :asc) }, dependent: :destroy

  validates :title, presence: true
  validate :customer_cannot_be_owner

  scope :for_user, ->(user) { where("customer_id = :uid OR owner_id = :uid", uid: user.id) }
  scope :recent, -> { order(updated_at: :desc) }

  def participant?(user)
    return false if user.blank?

    customer_id == user.id || owner_id == user.id
  end

  def interlocutor_for(user)
    return nil if user.blank?

    user.id == customer_id ? owner : customer
  end

  def role_for(user)
    return "" if user.blank?

    user.id == customer_id ? "Заказчик" : "Владелец объявления"
  end

  def other_role_for(user)
    return "" if user.blank?

    user.id == customer_id ? "Владелец объявления" : "Заказчик"
  end

  # Поиск или создание приватного диалога 1-на-1 между заказчиком и владельцем объявления
  def self.find_or_create_for_resource(customer:, resource:)
    owner = resource.user || User.first
    raise ArgumentError, "Нельзя начать чат с самим собой" if customer.id == owner.id

    find_or_create_by!(
      customer: customer,
      owner: owner,
      resource: resource,
      booking: nil
    ) do |room|
      room.title = "Чат по объявлению: #{resource.name}"
    end
  end

  # Поиск или создание приватного диалога 1-на-1 по бронированию
  def self.find_or_create_for_booking(booking)
    customer = booking.user
    owner = booking.resource.user || User.first
    raise ArgumentError, "Нельзя начать чат с самим собой" if customer.id == owner.id

    find_or_create_by!(
      booking: booking
    ) do |room|
      room.customer = customer
      room.owner = owner
      room.resource = booking.resource
      room.title = "Чат по бронированию ##{booking.id} — #{booking.resource_name}"
    end
  end

  private

  def customer_cannot_be_owner
    if customer_id.present? && owner_id.present? && customer_id == owner_id
      errors.add(:customer, "не может совпадать с владельцем объявления")
    end
  end
end
