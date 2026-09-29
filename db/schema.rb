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

ActiveRecord::Schema[8.1].define(version: 2026_09_29_120717) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "bookings", force: :cascade do |t|
    t.datetime "canceled_at"
    t.integer "canceled_by_id"
    t.datetime "created_at", null: false
    t.datetime "decided_at"
    t.integer "passenger_id", null: false
    t.text "pickup_notes"
    t.integer "ride_post_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["canceled_by_id"], name: "index_bookings_on_canceled_by_id"
    t.index ["passenger_id", "status"], name: "index_bookings_on_passenger_id_and_status"
    t.index ["ride_post_id", "passenger_id"], name: "index_bookings_on_ride_and_passenger_active", unique: true, where: "status IN (0, 1)"
    t.index ["ride_post_id", "status"], name: "index_bookings_on_ride_post_id_and_status"
  end

  create_table "chat_messages", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "ride_post_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["ride_post_id", "created_at"], name: "index_chat_messages_on_ride_post_id_and_created_at"
    t.index ["user_id"], name: "index_chat_messages_on_user_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "country_code"
    t.datetime "created_at", null: false
    t.integer "location_type"
    t.string "name"
    t.integer "parent_id"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_locations_on_parent_id"
    t.index ["slug"], name: "index_locations_on_slug", unique: true
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "actor_id"
    t.datetime "created_at", null: false
    t.datetime "delivered_at"
    t.string "delivery_key", null: false
    t.integer "delivery_status", default: 0, null: false
    t.string "event_name", null: false
    t.integer "notifiable_id", null: false
    t.string "notifiable_type", null: false
    t.datetime "read_at"
    t.integer "recipient_id", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["delivery_key"], name: "index_notifications_on_delivery_key", unique: true
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["recipient_id", "read_at"], name: "index_notifications_on_recipient_id_and_read_at"
  end

  create_table "ride_posts", force: :cascade do |t|
    t.integer "community_id"
    t.datetime "created_at", null: false
    t.datetime "departure_time"
    t.integer "destination_id", null: false
    t.datetime "expected_arrival_at"
    t.boolean "is_free_ride", default: false, null: false
    t.boolean "ladies_only", default: false, null: false
    t.text "notes"
    t.integer "origin_id", null: false
    t.integer "post_type"
    t.integer "remaining_seats"
    t.integer "seats"
    t.boolean "share_tolls", default: false, null: false
    t.boolean "split_gas", default: false, null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "visibility", default: 0, null: false
    t.index ["community_id"], name: "index_ride_posts_on_community_id"
    t.index ["destination_id"], name: "index_ride_posts_on_destination_id"
    t.index ["origin_id"], name: "index_ride_posts_on_origin_id"
    t.index ["user_id"], name: "index_ride_posts_on_user_id"
    t.check_constraint "NOT (is_free_ride = 1 AND (share_tolls = 1 OR split_gas = 1))", name: "check_ride_posts_cost_sharing"
    t.check_constraint "post_type != 0 OR remaining_seats IS NULL OR (remaining_seats >= 0 AND remaining_seats <= seats)", name: "check_ride_posts_offering_inventory"
    t.check_constraint "seats > 0", name: "check_ride_posts_seats_positive"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "subscribers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.datetime "unsubscribed_at"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "banned_at"
    t.datetime "booking_freeze_until"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "facebook_profile_url"
    t.string "first_name"
    t.integer "gender", default: 0, null: false
    t.string "last_name"
    t.string "password_digest", null: false
    t.string "unconfirmed_email"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bookings", "ride_posts"
  add_foreign_key "bookings", "users", column: "canceled_by_id", on_delete: :nullify
  add_foreign_key "bookings", "users", column: "passenger_id"
  add_foreign_key "chat_messages", "ride_posts"
  add_foreign_key "chat_messages", "users"
  add_foreign_key "locations", "locations", column: "parent_id"
  add_foreign_key "notifications", "users", column: "actor_id", on_delete: :nullify
  add_foreign_key "notifications", "users", column: "recipient_id"
  add_foreign_key "ride_posts", "locations", column: "destination_id"
  add_foreign_key "ride_posts", "locations", column: "origin_id"
  add_foreign_key "ride_posts", "users"
  add_foreign_key "sessions", "users"
end
