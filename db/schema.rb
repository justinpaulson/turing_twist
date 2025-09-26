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

ActiveRecord::Schema[8.0].define(version: 2025_09_25_211602) do
  create_table "answers", force: :cascade do |t|
    t.integer "round_id", null: false
    t.integer "player_id", null: false
    t.text "content"
    t.datetime "submitted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_answers_on_player_id"
    t.index ["round_id"], name: "index_answers_on_round_id"
  end

  create_table "games", force: :cascade do |t|
    t.integer "status"
    t.integer "round_count"
    t.integer "current_round"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "players", force: :cascade do |t|
    t.integer "game_id", null: false
    t.integer "user_id"
    t.boolean "is_ai", default: false
    t.boolean "is_eliminated", default: false
    t.text "ai_persona"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_players_on_game_id"
    t.index ["user_id"], name: "index_players_on_user_id"
  end

  create_table "rounds", force: :cascade do |t|
    t.integer "game_id", null: false
    t.integer "round_number"
    t.text "question"
    t.integer "status"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id"], name: "index_rounds_on_game_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "votes", force: :cascade do |t|
    t.integer "round_id", null: false
    t.integer "voter_id", null: false
    t.integer "voted_for_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["round_id"], name: "index_votes_on_round_id"
    t.index ["voted_for_id"], name: "index_votes_on_voted_for_id"
    t.index ["voter_id"], name: "index_votes_on_voter_id"
  end

  add_foreign_key "answers", "players"
  add_foreign_key "answers", "rounds"
  add_foreign_key "players", "games"
  add_foreign_key "players", "users"
  add_foreign_key "rounds", "games"
  add_foreign_key "sessions", "users"
  add_foreign_key "votes", "players", column: "voted_for_id"
  add_foreign_key "votes", "players", column: "voter_id"
  add_foreign_key "votes", "rounds"
end
