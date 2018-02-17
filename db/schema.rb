# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 0) do

  create_table "co_art_map", primary_key: "rowid", force: :cascade do |t|
    t.integer "id",  limit: 4
    t.string  "art", limit: 255
  end

  create_table "co_block", primary_key: "rowid", force: :cascade do |t|
    t.integer "time",        limit: 4
    t.integer "user",        limit: 4
    t.integer "wid",         limit: 4
    t.integer "x",           limit: 4
    t.integer "y",           limit: 4
    t.integer "z",           limit: 4
    t.integer "type",        limit: 4
    t.integer "data",        limit: 4
    t.binary  "meta",        limit: 65535
    t.integer "action",      limit: 4
    t.boolean "rolled_back"
  end

  add_index "co_block", ["data", "time"], name: "data", using: :btree
  add_index "co_block", ["type", "time"], name: "type", using: :btree
  add_index "co_block", ["user", "action", "time"], name: "user_action", using: :btree
  add_index "co_block", ["user", "time"], name: "user", using: :btree
  add_index "co_block", ["wid", "x", "z", "time"], name: "wid", using: :btree

  create_table "co_chat", primary_key: "rowid", force: :cascade do |t|
    t.integer "time",    limit: 4
    t.integer "user",    limit: 4
    t.string  "message", limit: 255
  end

  add_index "co_chat", ["time"], name: "time", using: :btree
  add_index "co_chat", ["user", "time"], name: "user", using: :btree

  create_table "co_command", primary_key: "rowid", force: :cascade do |t|
    t.integer "time",    limit: 4
    t.integer "user",    limit: 4
    t.string  "message", limit: 255
  end

  add_index "co_command", ["time"], name: "time", using: :btree
  add_index "co_command", ["user", "time"], name: "user", using: :btree

  create_table "co_container", primary_key: "rowid", force: :cascade do |t|
    t.integer "time",        limit: 4
    t.integer "user",        limit: 4
    t.integer "wid",         limit: 4
    t.integer "x",           limit: 4
    t.integer "y",           limit: 4
    t.integer "z",           limit: 4
    t.integer "type",        limit: 4
    t.integer "data",        limit: 4
    t.integer "amount",      limit: 4
    t.binary  "metadata",    limit: 65535
    t.integer "action",      limit: 4
    t.boolean "rolled_back"
  end

  add_index "co_container", ["type", "time"], name: "type", using: :btree
  add_index "co_container", ["user", "time"], name: "user", using: :btree
  add_index "co_container", ["wid", "x", "z", "time"], name: "wid", using: :btree

  create_table "co_entity", primary_key: "rowid", force: :cascade do |t|
    t.integer "time", limit: 4
    t.binary  "data", limit: 65535
  end

  create_table "co_entity_map", primary_key: "rowid", force: :cascade do |t|
    t.integer "id",     limit: 4
    t.string  "entity", limit: 255
  end

  create_table "co_material_map", primary_key: "rowid", force: :cascade do |t|
    t.integer "id",       limit: 4
    t.string  "material", limit: 255
  end

  create_table "co_session", primary_key: "rowid", force: :cascade do |t|
    t.integer "time",   limit: 4
    t.integer "user",   limit: 4
    t.integer "wid",    limit: 4
    t.integer "x",      limit: 4
    t.integer "y",      limit: 4
    t.integer "z",      limit: 4
    t.integer "action", limit: 4
  end

  add_index "co_session", ["action", "time"], name: "action", using: :btree
  add_index "co_session", ["time"], name: "time", using: :btree
  add_index "co_session", ["user", "time"], name: "user", using: :btree
  add_index "co_session", ["wid", "x", "z", "time"], name: "wid", using: :btree

  create_table "co_sign", primary_key: "rowid", force: :cascade do |t|
    t.integer "time",   limit: 4
    t.integer "user",   limit: 4
    t.integer "wid",    limit: 4
    t.integer "x",      limit: 4
    t.integer "y",      limit: 4
    t.integer "z",      limit: 4
    t.string  "line_1", limit: 100
    t.string  "line_2", limit: 100
    t.string  "line_3", limit: 100
    t.string  "line_4", limit: 100
  end

  add_index "co_sign", ["wid", "x", "z", "y", "time"], name: "wid", using: :btree

  create_table "co_skull", primary_key: "rowid", force: :cascade do |t|
    t.integer "time",     limit: 4
    t.integer "type",     limit: 4
    t.integer "data",     limit: 4
    t.integer "rotation", limit: 4
    t.string  "owner",    limit: 16
  end

  create_table "co_user", primary_key: "rowid", force: :cascade do |t|
    t.integer "time", limit: 4
    t.string  "user", limit: 64
    t.string  "uuid", limit: 64
  end

  add_index "co_user", ["user"], name: "user", using: :btree
  add_index "co_user", ["uuid"], name: "uuid", using: :btree

  create_table "co_username_log", primary_key: "rowid", force: :cascade do |t|
    t.integer "time", limit: 4
    t.string  "uuid", limit: 64
    t.string  "user", limit: 32
  end

  add_index "co_username_log", ["uuid", "user"], name: "uuid", using: :btree

  create_table "co_version", primary_key: "rowid", force: :cascade do |t|
    t.integer "time",    limit: 4
    t.string  "version", limit: 16
  end

  create_table "co_world", primary_key: "rowid", force: :cascade do |t|
    t.integer "id",    limit: 4
    t.string  "world", limit: 255
  end

end
