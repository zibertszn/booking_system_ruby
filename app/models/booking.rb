# frozen_string_literal: true

class Booking < ApplicationRecord
  belongs_to :user
  belongs_to :resource
  has_one :chat_room, dependent: :destroy

  delegate :name, :slug, to: :resource, prefix: true, allow_nil: true

  STATUSES = %w[confirmed cancelled].freeze

  before_validation :compute_timestamps_and_price

  validates :booking_date, :start_time, :end_time, :starts_at, :ends_at, :total_price, presence: true
  validates :contact_name, :contact_email, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate  :end_time_after_start_time
  validate  :booking_within_resource_availability
  validate  :user_cannot_book_own_resource
  validate  :no_overlapping_confirmed_bookings, if: -> { status == "confirmed" }

  after_create_commit :deliver_confirmation_notification

  scope :confirmed, -> { where(status: "confirmed") }
  scope :cancelled, -> { where(status: "cancelled") }
  scope :recent,    -> { order(booking_date: :desc, start_time: :asc) }

  def overlaps_hours?(other_start_str, other_end_str)
    s_a = self.class.time_to_minutes(start_time)
    e_a = self.class.time_to_minutes(end_time)
    s_b = self.class.time_to_minutes(other_start_str)
    e_b = self.class.time_to_minutes(other_end_str)
    [s_a, s_b].max < [e_a, e_b].min
  end

  def cancel!
    update!(status: "cancelled")
    BookingMailer.cancellation_email(self).deliver_later
  end

  def self.time_to_minutes(str)
    parts = str.to_s.split(":").map(&:to_i)
    (parts[0] || 0) * 60 + (parts[1] || 0)
  end

  private

  def compute_timestamps_and_price
    return if booking_date.blank? || start_time.blank? || end_time.blank? || resource.blank?

    self.starts_at = Time.zone.parse("#{booking_date} #{start_time}")
    self.ends_at   = Time.zone.parse("#{booking_date} #{end_time}")
    self.booking_period = (starts_at...ends_at)

    minutes = self.class.time_to_minutes(end_time) - self.class.time_to_minutes(start_time)
    self.duration_hours = [(minutes / 60.0).ceil, 1].max
    self.total_price    = duration_hours * (resource.respond_to?(:effective_hourly_rate) ? resource.effective_hourly_rate : resource.hourly_rate)
  end

  def end_time_after_start_time
    return if starts_at.blank? || ends_at.blank?

    if ends_at <= starts_at
      errors.add(:end_time, "должно быть позже времени начала")
    end
  end

  def booking_within_resource_availability
    return if resource.blank? || booking_date.blank? || start_time.blank? || end_time.blank?

    if resource.available_from_date.present? && booking_date < resource.available_from_date
      errors.add(:booking_date, "не может быть раньше начала периода доступности ресурса (#{resource.available_from_date.strftime('%d.%m.%Y')})")
    end

    if resource.available_to_date.present? && booking_date > resource.available_to_date
      errors.add(:booking_date, "не может быть позже окончания периода доступности ресурса (#{resource.available_to_date.strftime('%d.%m.%Y')})")
    end

    b_start_min = self.class.time_to_minutes(start_time)
    b_end_min   = self.class.time_to_minutes(end_time)

    res_from = resource.available_from_time.presence || "09:00"
    res_to   = resource.available_to_time.presence || "21:00"

    res_start_min = self.class.time_to_minutes(res_from)
    res_end_min   = res_to.start_with?("24") ? 1440 : self.class.time_to_minutes(res_to)

    if b_start_min < res_start_min || b_end_min > res_end_min
      errors.add(:base, "Бронирование возможно только в интервале доступности с #{res_from} до #{res_to}")
    end
  end

  def user_cannot_book_own_resource
    return if user_id.blank? || resource.blank?

    if resource.user_id.present? && resource.user_id == user_id
      errors.add(:base, "Вы не можете забронировать собственное объявление")
    end
  end

  # Проверка пересечения интервалов через оператор && типа tsrange в PostgreSQL
  def no_overlapping_confirmed_bookings
    return if resource_id.blank? || starts_at.blank? || ends_at.blank?

    conflict_Exists = Booking
      .where(resource_id: resource_id, status: "confirmed")
      .where.not(id: id)
      .where("booking_period && tsrange(?, ?, '[)')", starts_at, ends_at)
      .exists?

    if conflict_Exists
      errors.add(:base, "Выбранный интервал времени уже занят другим бронированием (защита tsrange GiST)")
    end
  end

  def deliver_confirmation_notification
    BookingMailer.confirmation_email(self).deliver_later
  end
end
