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

ActiveRecord::Schema[8.0].define(version: 2025_11_12_012634) do
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
    t.index ["membership_id"], name: "index_assignments_on_membership_id"
    t.index ["task_id"], name: "index_assignments_on_task_id"
  end

  create_table "evaluations", force: :cascade do |t|
    t.bigint "assignment_id", null: false
    t.integer "evaluator_id"
    t.integer "score"
    t.text "feedback"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignment_id"], name: "index_evaluations_on_assignment_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "name"
    t.string "share_key"
    t.string "assign_mode"
    t.string "balance_type"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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

  create_table "tasks", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.string "name"
    t.integer "point"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_tasks_on_group_id"
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
  add_foreign_key "evaluations", "assignments"
  add_foreign_key "memberships", "groups"
  add_foreign_key "memberships", "users"
  add_foreign_key "tasks", "groups"
end
