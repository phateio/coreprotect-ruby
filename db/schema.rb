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

  create_table "co_art_map", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "id"
    t.string "art"
    t.index ["id"], name: "id"
  end

  create_table "co_block", primary_key: "rowid", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "time"
    t.integer "user"
    t.integer "wid"
    t.integer "x"
    t.integer "y"
    t.integer "z"
    t.integer "type"
    t.integer "data"
    t.binary "meta", limit: 16777215
    t.binary "blockdata"
    t.integer "action"
    t.boolean "rolled_back"
    t.index ["type", "time"], name: "type"
    t.index ["user", "time"], name: "user"
    t.index ["wid", "x", "z", "time"], name: "wid"
  end

  create_table "co_blockdata_map", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "id"
    t.string "data"
    t.index ["id"], name: "id"
  end

  create_table "co_chat", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "time"
    t.integer "user"
    t.integer "wid"
    t.integer "x"
    t.integer "y"
    t.integer "z"
    t.string "message", limit: 1000
    t.index ["time"], name: "time"
    t.index ["user", "time"], name: "user"
    t.index ["wid", "x", "z", "time"], name: "wid"
  end

  create_table "co_command", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "time"
    t.integer "user"
    t.integer "wid"
    t.integer "x"
    t.integer "y"
    t.integer "z"
    t.string "message", limit: 1000
    t.index ["time"], name: "time"
    t.index ["user", "time"], name: "user"
    t.index ["wid", "x", "z", "time"], name: "wid"
  end

  create_table "co_container", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "time"
    t.integer "user"
    t.integer "wid"
    t.integer "x"
    t.integer "y"
    t.integer "z"
    t.integer "type"
    t.integer "data"
    t.integer "amount"
    t.binary "metadata"
    t.integer "action"
    t.boolean "rolled_back"
    t.index ["type", "time"], name: "type"
    t.index ["user", "time"], name: "user"
    t.index ["wid", "x", "z", "time"], name: "wid"
  end

  create_table "co_database_lock", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.boolean "status"
    t.integer "time"
  end

  create_table "co_entity", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "time"
    t.binary "data"
  end

  create_table "co_entity_map", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "id"
    t.string "entity"
    t.index ["id"], name: "id"
  end

  create_table "co_item", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "time"
    t.integer "user"
    t.integer "wid"
    t.integer "x"
    t.integer "y"
    t.integer "z"
    t.integer "type"
    t.binary "data"
    t.integer "amount"
    t.boolean "action"
    t.index ["type", "time"], name: "type"
    t.index ["user", "time"], name: "user"
    t.index ["wid", "x", "z", "time"], name: "wid"
  end

  create_table "co_material_map", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "id"
    t.string "material"
    t.index ["id"], name: "id"
  end

  create_table "co_session", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "time"
    t.integer "user"
    t.integer "wid"
    t.integer "x"
    t.integer "y"
    t.integer "z"
    t.integer "action"
    t.index ["action", "time"], name: "action"
    t.index ["time"], name: "time"
    t.index ["user", "time"], name: "user"
    t.index ["wid", "x", "z", "time"], name: "wid"
  end

  create_table "co_sign", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "time"
    t.integer "user"
    t.integer "wid"
    t.integer "x"
    t.integer "y"
    t.integer "z"
    t.integer "action"
    t.integer "color"
    t.string "line_1", limit: 100
    t.string "line_2", limit: 100
    t.string "line_3", limit: 100
    t.string "line_4", limit: 100
    t.index ["time"], name: "time"
    t.index ["user", "time"], name: "user"
    t.index ["wid", "x", "z", "time"], name: "wid"
  end

  create_table "co_skull", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "time"
    t.string "owner", limit: 64
  end

  create_table "co_user", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "time"
    t.string "user", limit: 100
    t.string "uuid", limit: 64
    t.index ["user"], name: "user"
    t.index ["uuid"], name: "uuid"
  end

  create_table "co_username_log", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "time"
    t.string "uuid", limit: 64
    t.string "user", limit: 100
    t.index ["uuid", "user"], name: "uuid"
  end

  create_table "co_version", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "time"
    t.string "version", limit: 16
  end

  create_table "co_world", primary_key: "rowid", id: :integer, options: "ENGINE=InnoDB DEFAULT CHARSET=utf8", force: :cascade do |t|
    t.integer "id"
    t.string "world"
    t.index ["id"], name: "id"
  end

end
