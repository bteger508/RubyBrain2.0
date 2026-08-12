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

ActiveRecord::Schema[8.1].define(version: 2026_08_12_000736) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "memories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.boolean "forgotten", default: false, null: false
    t.datetime "last_recalled_at"
    t.integer "recall_count", default: 0, null: false
    t.virtual "searchable", type: :tsvector, as: "(setweight(to_tsvector('english'::regconfig, (COALESCE(title, ''::character varying))::text), 'A'::\"char\") || setweight(to_tsvector('english'::regconfig, COALESCE(description, ''::text)), 'B'::\"char\"))", stored: true
    t.bigint "superseded_by_id"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_memories_on_created_at"
    t.index ["forgotten"], name: "index_memories_on_forgotten"
    t.index ["searchable"], name: "index_memories_on_searchable", using: :gin
    t.index ["superseded_by_id"], name: "index_memories_on_superseded_by_id"
    t.index ["title"], name: "index_memories_on_title_trigram", opclass: :gin_trgm_ops, using: :gin
  end

  add_foreign_key "memories", "memories", column: "superseded_by_id"
end
