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

ActiveRecord::Schema[8.1].define(version: 2026_02_06_233544) do
  create_table "contacts", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "labelings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "label_id", null: false
    t.integer "message_id", null: false
    t.datetime "updated_at", null: false
    t.index ["label_id"], name: "index_labelings_on_label_id"
    t.index ["message_id", "label_id"], name: "index_labelings_on_message_id_and_label_id", unique: true
    t.index ["message_id"], name: "index_labelings_on_message_id"
  end

  create_table "labels", force: :cascade do |t|
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_labels_on_name", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "label", default: "inbox", null: false
    t.datetime "read_at"
    t.integer "recipient_id", null: false
    t.integer "replied_to_id"
    t.integer "sender_id", null: false
    t.boolean "starred", default: false, null: false
    t.string "subject", null: false
    t.datetime "updated_at", null: false
    t.index ["label"], name: "index_messages_on_label"
    t.index ["read_at"], name: "index_messages_on_read_at"
    t.index ["recipient_id"], name: "index_messages_on_recipient_id"
    t.index ["replied_to_id"], name: "index_messages_on_replied_to_id"
    t.index ["sender_id"], name: "index_messages_on_sender_id"
    t.index ["starred"], name: "index_messages_on_starred"
  end

  add_foreign_key "labelings", "labels"
  add_foreign_key "labelings", "messages"
  add_foreign_key "messages", "contacts", column: "recipient_id"
  add_foreign_key "messages", "contacts", column: "sender_id"
  add_foreign_key "messages", "messages", column: "replied_to_id"
end
