# frozen_string_literal: true

class Resource < ApplicationRecord
  BUSINESS_START_HOUR = 9
  BUSINESS_END_HOUR   = 21

  CATEGORIES = {
    "rooms"       => "Помещение",
    "equipment"   => "Оборудование",
    "specialists" => "Специалисты"
  }.freeze

  RATE_UNITS = {
    "hour"  => "в час",
    "day"   => "в день",
    "month" => "в месяц",
    "year"  => "в год"
  }.freeze

  RATE_UNIT_LABELS = {
    "hour"  => "час",
    "day"   => "день",
    "month" => "месяц",
    "year"  => "год"
  }.freeze

  alias_attribute :rate, :hourly_rate
  alias_attribute :price, :hourly_rate

  # Поддержка ActiveStorage для загрузки файлов изображений плюс хранение пути в image_url
  has_one_attached :image if defined?(ActiveStorage)
  belongs_to :user, optional: true
  has_many :bookings, dependent: :destroy
  has_many :chat_rooms, dependent: :destroy

  before_validation :assign_default_slug_and_category_name
  before_validation :normalize_rate_unit
  before_validation :normalize_capacity
  before_validation :normalize_availability_times

  validates :slug, :name, :category, :category_name, :description, :hourly_rate, :rate_unit, presence: true
  validates :available_from_time, :available_to_time, presence: true
  validates :slug, uniqueness: true
  validates :category, inclusion: { in: CATEGORIES.keys }
  validates :hourly_rate, numericality: { greater_than: 0 }
  validates :rate_unit, inclusion: { in: RATE_UNITS.keys }
  validate  :available_hours_order
  validate  :available_dates_order

  scope :by_category, ->(cat) { where(category: cat) if cat.present? && cat != "all" }
  scope :search_query, ->(q) {
    if q.present?
      pattern = "%#{sanitize_sql_like(q.strip)}%"
      where("name ILIKE :p OR description ILIKE :p OR location ILIKE :p", p: pattern)
    end
  }

  def rate_unit_label
    RATE_UNIT_LABELS[rate_unit] || "час"
  end

  def rate_unit_title
    RATE_UNITS[rate_unit] || "в час"
  end

  def owned_by?(user)
    user.present? && user_id.present? && user_id == user.id
  end

  # Расчетный почасовой тариф для совместимости с почасовым календарем бронирования
  def effective_hourly_rate
    case rate_unit
    when "day"
      [(hourly_rate / 12.0).round, 1].max
    when "month"
      [(hourly_rate / (22.0 * 12)).round, 1].max
    when "year"
      [(hourly_rate / (250.0 * 12)).round, 1].max
    else
      hourly_rate
    end
  end

  def available_start_hour
    (available_from_time.presence || "09:00").split(":").first.to_i
  end

  def available_end_hour
    val = (available_to_time.presence || "21:00")
    val.start_with?("24") ? 24 : val.split(":").first.to_i
  end

  def available_for_date?(date)
    return true if date.blank?
    target = date.is_a?(Date) ? date : Date.parse(date.to_s)
    return false if available_from_date.present? && target < available_from_date
    return false if available_to_date.present? && target > available_to_date
    true
  rescue ArgumentError
    false
  end

  def availability_hours_label
    "#{available_from_time || '09:00'} – #{available_to_time || '21:00'}"
  end

  def availability_dates_label
    if available_from_date.present? && available_to_date.present?
      "с #{available_from_date.strftime('%d.%m.%Y')} по #{available_to_date.strftime('%d.%m.%Y')}"
    elsif available_from_date.present?
      "с #{available_from_date.strftime('%d.%m.%Y')}"
    elsif available_to_date.present?
      "по #{available_to_date.strftime('%d.%m.%Y')}"
    else
      "в любые дни"
    end
  end

  # Формирует почасовую сетку слотов в интервале доступности ресурса для реактивного виджета Vue.js
  def hourly_slots_for(date_str)
    target_date = Date.parse(date_str.to_s)
    return [] unless available_for_date?(target_date)

    s_hour = [available_start_hour, 0].max
    e_hour = [available_end_hour, 24].min
    return [] if s_hour >= e_hour

    confirmed_bookings = bookings.where(booking_date: target_date, status: "confirmed")

    (s_hour...e_hour).map do |hour|
      slot_start = format("%02d:00", hour)
      slot_end   = format("%02d:00", hour + 1)

      overlapping = confirmed_bookings.find do |b|
        b.overlaps_hours?(slot_start, slot_end)
      end

      {
        hour: hour,
        time_label: slot_start,
        end_label: slot_end,
        available: overlapping.nil?,
        booked_by: overlapping&.contact_name
      }
    end
  rescue ArgumentError
    []
  end

  private

  def normalize_availability_times
    self.available_from_time = "09:00" if available_from_time.blank?
    self.available_to_time   = "21:00" if available_to_time.blank?
  end

  def available_hours_order
    return if available_from_time.blank? || available_to_time.blank?

    s_min = Booking.time_to_minutes(available_from_time)
    e_min = available_to_time.start_with?("24") ? 1440 : Booking.time_to_minutes(available_to_time)

    if s_min >= e_min
      errors.add(:available_to_time, "должно быть позже времени начала доступности")
    end
  end

  def available_dates_order
    return if available_from_date.blank? || available_to_date.blank?

    if available_from_date > available_to_date
      errors.add(:available_to_date, "не может быть раньше даты начала доступности")
    end
  end

  def assign_default_slug_and_category_name
    self.category_name = CATEGORIES[category] || "Помещение" if category.present?
    if new_record? && slug.blank? && name.present?
      self.slug = "res_#{Time.now.to_i}_#{rand(100..999)}"
    end
  end

  def normalize_rate_unit
    if !%w[rooms equipment].include?(category) || rate_unit.blank?
      self.rate_unit = "hour"
    end
  end

  def normalize_capacity
    self.capacity = nil if category != "rooms"
  end
end
