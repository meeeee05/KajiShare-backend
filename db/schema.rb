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

ActiveRecord::Schema[8.0].define(version: 2026_05_05_174500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "assignments", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.integer "assigned_to_id"
    t.integer "assigned_by_id"
    t.date "due_date"
    t.date "completed_date"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "membership_id", null: false
    t.string "status", default: "着手前"
    t.bigint "completed_by_user_id"
    t.datetime "assigned_at"
    t.index ["assigned_at"], name: "index_assignments_on_assigned_at"
    t.index ["completed_by_user_id"], name: "index_assignments_on_completed_by_user_id"
    t.index ["membership_id"], name: "index_assignments_on_membership_id"
    t.index ["task_id", "membership_id"], name: "index_assignments_on_task_id_and_membership_id", unique: true
  end

  create_table "evaluations", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.integer "evaluator_id"
    t.integer "score"
    t.text "feedback"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignment_id", "evaluator_id"], name: "index_evaluations_on_assignment_and_evaluator", unique: true
  end

  create_table "groups", force: :cascade do |t|
    t.string "name"
    t.string "share_key"
    t.string "assign_mode"
    t.string "balance_type"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.index ["created_by_id"], name: "index_groups_on_created_by_id"
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "group_id", null: false
    t.string "role"
    t.float "workload_ratio"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "active"
    t.index ["group_id"], name: "index_memberships_on_group_id"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "notification_events", force: :cascade do |t|
    t.string "event_type", null: false
    t.bigint "recipient_user_id", null: false
    t.bigint "actor_user_id"
    t.bigint "group_id"
    t.bigint "task_id"
    t.bigint "assignment_id"
    t.datetime "occurred_at", null: false
    t.jsonb "payload", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignment_id"], name: "index_notification_events_on_assignment_id"
    t.index ["recipient_user_id", "event_type", "occurred_at"], name: "index_notification_events_on_recipient_event_time"
  end

  create_table "recurring_tasks", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "point", null: false
    t.string "schedule_type", null: false
    t.integer "day_of_week"
    t.integer "interval_days"
    t.date "starts_on", null: false
    t.boolean "active", default: true, null: false
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_recurring_tasks_on_active"
    t.index ["created_by_id"], name: "index_recurring_tasks_on_created_by_id"
    t.index ["group_id"], name: "index_recurring_tasks_on_group_id"
    t.index ["schedule_type"], name: "index_recurring_tasks_on_schedule_type"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.string "name"
    t.integer "point"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "source_recurring_task_id"
    t.date "scheduled_for"
    t.boolean "auto_generated", default: false, null: false
    t.index ["group_id", "name"], name: "index_tasks_on_group_id_and_name_manual", unique: true, where: "(scheduled_for IS NULL)"
    t.index ["group_id", "source_recurring_task_id", "scheduled_for"], name: "index_tasks_on_group_recurring_source_and_scheduled_for", unique: true
    t.index ["group_id"], name: "index_tasks_on_group_id"
    t.index ["source_recurring_task_id"], name: "index_tasks_on_source_recurring_task_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "google_sub"
    t.string "name"
    t.string "email"
    t.string "picture"
    t.string "account_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "assignments", "memberships"
  add_foreign_key "assignments", "tasks"
  add_foreign_key "assignments", "users", column: "completed_by_user_id"
  add_foreign_key "evaluations", "assignments"
  add_foreign_key "groups", "users", column: "created_by_id"
  add_foreign_key "memberships", "groups"
  add_foreign_key "memberships", "users"
  add_foreign_key "notification_events", "assignments"
  add_foreign_key "notification_events", "groups"
  add_foreign_key "notification_events", "tasks"
  add_foreign_key "notification_events", "users", column: "actor_user_id"
  add_foreign_key "notification_events", "users", column: "recipient_user_id"
  add_foreign_key "recurring_tasks", "groups"
  add_foreign_key "recurring_tasks", "users", column: "created_by_id"
  add_foreign_key "tasks", "groups"
  add_foreign_key "tasks", "recurring_tasks", column: "source_recurring_task_id"
end
