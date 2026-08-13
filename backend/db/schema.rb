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

ActiveRecord::Schema[8.1].define(version: 2026_08_12_120003) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"

  create_table "bookings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "booked_at", null: false
    t.string "booked_timezone"
    t.text "cancellation_reason"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.string "idempotency_key", null: false
    t.uuid "member_id", null: false
    t.uuid "organization_id", null: false
    t.uuid "slot_id", null: false
    t.string "status", default: "confirmed", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_bookings_on_idempotency_key", unique: true
    t.index ["member_id", "organization_id", "status"], name: "index_bookings_on_member_org_status"
    t.index ["member_id", "status"], name: "index_bookings_on_member_id_and_status"
    t.index ["member_id"], name: "index_bookings_on_member_id"
    t.index ["organization_id"], name: "index_bookings_on_organization_id"
    t.index ["slot_id"], name: "index_bookings_on_slot_id"
    t.index ["slot_id"], name: "index_bookings_on_slot_id_active_unique", unique: true, where: "((status)::text <> 'cancelled'::text)"
  end

  create_table "mentor_profiles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "bio", null: false
    t.datetime "created_at", null: false
    t.string "expertise", default: [], null: false, array: true
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["expertise"], name: "index_mentor_profiles_on_expertise_gin", using: :gin
    t.index ["user_id"], name: "index_mentor_profiles_on_user_id", unique: true
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body", null: false
    t.uuid "booking_id"
    t.datetime "created_at", null: false
    t.string "notification_type", null: false
    t.uuid "organization_id", null: false
    t.boolean "read", default: false, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["booking_id"], name: "index_notifications_on_booking_id"
    t.index ["organization_id"], name: "index_notifications_on_organization_id"
    t.index ["user_id", "read", "created_at"], name: "index_notifications_on_user_read_created"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "organizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "max_active_bookings", default: 5
    t.string "name", null: false
    t.string "timezone", default: "UTC", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pre_session_briefs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "booking_id", null: false
    t.integer "completion_tokens"
    t.text "content"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "model_used"
    t.integer "prompt_tokens"
    t.string "status", default: "pending", null: false
    t.integer "total_tokens"
    t.datetime "updated_at", null: false
    t.index ["booking_id"], name: "index_pre_session_briefs_on_booking_id", unique: true
  end

  create_table "slots", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "buffer_minutes", default: 15
    t.datetime "created_at", null: false
    t.datetime "end_time", null: false
    t.uuid "mentor_id", null: false
    t.uuid "organization_id", null: false
    t.datetime "start_time", null: false
    t.string "status", default: "available", null: false
    t.datetime "updated_at", null: false
    t.index ["mentor_id", "start_time"], name: "index_slots_on_mentor_id_and_start_time", unique: true
    t.index ["mentor_id", "status", "start_time"], name: "index_slots_on_mentor_id_and_status_and_start_time"
    t.index ["mentor_id"], name: "index_slots_on_mentor_id"
    t.index ["organization_id"], name: "index_slots_on_organization_id"
    t.index ["start_time"], name: "index_slots_on_start_time"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.uuid "organization_id", null: false
    t.string "password_digest"
    t.string "role", default: "member", null: false
    t.string "timezone"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_users_on_name_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["organization_id", "email"], name: "index_users_on_organization_id_and_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
  end

  add_foreign_key "bookings", "organizations"
  add_foreign_key "bookings", "slots"
  add_foreign_key "bookings", "users", column: "member_id"
  add_foreign_key "mentor_profiles", "users"
  add_foreign_key "notifications", "bookings"
  add_foreign_key "notifications", "organizations"
  add_foreign_key "notifications", "users"
  add_foreign_key "pre_session_briefs", "bookings"
  add_foreign_key "slots", "organizations"
  add_foreign_key "slots", "users", column: "mentor_id"
  add_foreign_key "users", "organizations"
end
