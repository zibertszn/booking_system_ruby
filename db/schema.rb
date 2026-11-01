# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2026_11_02_020000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "bookings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "resource_id", null: false
    t.date "booking_date", null: false
    t.string "start_time", null: false
    t.string "end_time", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.tsrange "booking_period", null: false
    t.integer "duration_hours", default: 1, null: false
    t.integer "total_price", null: false
    t.string "status", default: "confirmed", null: false
    t.string "purpose"
    t.string "contact_name", null: false
    t.string "contact_email", null: false
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["booking_period"], name: "index_bookings_on_booking_period", using: :gist
    t.index ["resource_id", "booking_date"], name: "index_bookings_on_resource_id_and_booking_date"
    t.index ["resource_id"], name: "index_bookings_on_resource_id"
    t.index ["user_id"], name: "index_bookings_on_user_id"
    t.exclusion_constraint "resource_id WITH =, booking_period WITH &&", where: "(status)::text = 'confirmed'::text", using: :gist, name: "bookings_resource_period_no_overlap"
  end

  create_table "chat_messages", force: :cascade do |t|
    t.bigint "chat_room_id", null: false
    t.bigint "user_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_room_id"], name: "index_chat_messages_on_chat_room_id"
    t.index ["user_id"], name: "index_chat_messages_on_user_id"
  end

  create_table "chat_rooms", force: :cascade do |t|
    t.string "title", null: false
    t.bigint "booking_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "customer_id", null: false
    t.bigint "owner_id", null: false
    t.bigint "resource_id"
    t.index ["booking_id"], name: "index_chat_rooms_on_booking_id"
    t.index ["customer_id", "owner_id", "resource_id"], name: "index_chat_rooms_on_customer_id_and_owner_id_and_resource_id"
    t.index ["customer_id"], name: "index_chat_rooms_on_customer_id"
    t.index ["owner_id"], name: "index_chat_rooms_on_owner_id"
    t.index ["resource_id"], name: "index_chat_rooms_on_resource_id"
  end

  create_table "resources", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.string "category", null: false
    t.string "category_name", null: false
    t.text "description", null: false
    t.string "location"
    t.integer "capacity"
    t.integer "hourly_rate", null: false
    t.string "amenities", default: [], array: true
    t.string "image_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "rate_unit", default: "hour", null: false
    t.bigint "user_id"
    t.string "available_from_time", default: "09:00", null: false
    t.string "available_to_time", default: "21:00", null: false
    t.date "available_from_date"
    t.date "available_to_date"
    t.index ["category"], name: "index_resources_on_category"
    t.index ["slug"], name: "index_resources_on_slug", unique: true
    t.index ["user_id"], name: "index_resources_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", default: "", null: false
    t.string "phone", default: ""
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bookings", "resources"
  add_foreign_key "bookings", "users"
  add_foreign_key "chat_messages", "chat_rooms"
  add_foreign_key "chat_messages", "users"
  add_foreign_key "chat_rooms", "bookings"
  add_foreign_key "chat_rooms", "resources"
  add_foreign_key "chat_rooms", "users", column: "customer_id"
  add_foreign_key "chat_rooms", "users", column: "owner_id"
  add_foreign_key "resources", "users"
end
