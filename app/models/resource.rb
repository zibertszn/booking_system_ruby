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

  before_validation :assign_default_slug_and_category_name
  before_validation :normalize_rate_unit
  before_validation :normalize_capacity

  validates :slug, :name, :category, :category_name, :description, :hourly_rate, :rate_unit, presence: true
  validates :slug, uniqueness: true
  validates :category, inclusion: { in: CATEGORIES.keys }
  validates :hourly_rate, numericality: { greater_than: 0 }
  validates :rate_unit, inclusion: { in: RATE_UNITS.keys }

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

  # Формирует почасовую сетку слотов 09:00..21:00 для реактивного виджета Vue.js
  def hourly_slots_for(date_str)
    target_date = Date.parse(date_str.to_s)
    confirmed_bookings = bookings.where(booking_date: target_date, status: "confirmed")

    (BUSINESS_START_HOUR...BUSINESS_END_HOUR).map do |hour|
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
  end

  private

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
