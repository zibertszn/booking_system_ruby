# frozen_string_literal: true

class CreateBookingsWithTsrangeGist < ActiveRecord::Migration[7.1]
  def change
    # Включаем расширение PostgreSQL btree_gist для комбинирования "=" (integer) и "&&" (tsrange) в GiST-индексе
    enable_extension "btree_gist" unless extension_enabled?("btree_gist")

    create_table :bookings do |t|
      t.references :user,           null: false, foreign_key: true
      t.references :resource,       null: false, foreign_key: true
      t.date       :booking_date,   null: false
      t.string     :start_time,     null: false
      t.string     :end_time,       null: false
      t.datetime   :starts_at,      null: false
      t.datetime   :ends_at,        null: false
      t.tsrange    :booking_period, null: false
      t.integer    :duration_hours, null: false, default: 1
      t.integer    :total_price,    null: false
      t.string     :status,         null: false, default: "confirmed"
      t.string     :purpose
      t.string     :contact_name,   null: false
      t.string     :contact_email,  null: false
      t.string     :contact_phone

      t.timestamps
    end

    add_index :bookings, [:resource_id, :booking_date]
    add_index :bookings, :booking_period, using: :gist

    # Защита от двойного бронирования (овербукинга) на уровне самой СУБД PostgreSQL
    add_exclusion_constraint :bookings,
      "resource_id WITH =, booking_period WITH &&",
      using: :gist,
      where: "status = 'confirmed'",
      name: "bookings_resource_period_no_overlap"
  end
end
