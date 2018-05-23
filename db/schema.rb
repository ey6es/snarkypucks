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

ActiveRecord::Schema.define(version: 20151216000543) do

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   default: 0, null: false
    t.integer  "attempts",   default: 0, null: false
    t.text     "handler",                null: false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority"

  create_table "game_invites", force: :cascade do |t|
    t.integer  "game_id"
    t.integer  "sender_id"
    t.string   "message"
    t.integer  "player_id"
    t.string   "fb_request_id"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "game_invites", ["fb_request_id"], name: "index_game_invites_on_fb_request_id"
  add_index "game_invites", ["game_id"], name: "index_game_invites_on_game_id"
  add_index "game_invites", ["player_id"], name: "index_game_invites_on_player_id"
  add_index "game_invites", ["sender_id"], name: "index_game_invites_on_sender_id"

  create_table "game_members", force: :cascade do |t|
    t.integer  "game_id"
    t.integer  "player_id"
    t.text     "move"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text     "secret"
  end

  add_index "game_members", ["game_id"], name: "index_game_members_on_game_id"
  add_index "game_members", ["player_id"], name: "index_game_members_on_player_id"

  create_table "games", force: :cascade do |t|
    t.string   "title"
    t.integer  "track_revision_id"
    t.integer  "turn_interval"
    t.boolean  "early_turns"
    t.integer  "min_players"
    t.integer  "max_players"
    t.boolean  "open_to_all"
    t.boolean  "open_to_friends"
    t.text     "results"
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
    t.datetime "last_move_time"
    t.integer  "moves_per_turn"
    t.float    "move_distance"
    t.integer  "prompts_per_turn"
    t.text     "secret"
    t.boolean  "finished"
    t.datetime "start_time"
    t.integer  "turn_number"
    t.boolean  "finishing",         default: false, null: false
  end

  add_index "games", ["open_to_all"], name: "index_games_on_open_to_all"
  add_index "games", ["start_time"], name: "index_games_on_start_time"
  add_index "games", ["track_revision_id"], name: "index_games_on_track_revision_id"

  create_table "players", force: :cascade do |t|
    t.string   "name"
    t.string   "email"
    t.string   "password_digest"
    t.boolean  "admin"
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.string   "code"
    t.boolean  "verified"
    t.boolean  "completed_tutorial"
    t.string   "fb_email"
    t.boolean  "email_notifications"
    t.string   "push_endpoint"
    t.integer  "games_played",        default: 0, null: false
    t.integer  "games_won",           default: 0, null: false
    t.integer  "prompts_answered",    default: 0, null: false
    t.integer  "prompts_won",         default: 0, null: false
    t.integer  "votes_received",      default: 0, null: false
    t.integer  "rating",              default: 0, null: false
    t.integer  "prompt_rating",       default: 0, null: false
  end

  add_index "players", ["code"], name: "index_players_on_code"
  add_index "players", ["email"], name: "index_players_on_email", unique: true
  add_index "players", ["games_played"], name: "index_players_on_games_played"
  add_index "players", ["games_won"], name: "index_players_on_games_won"
  add_index "players", ["name"], name: "index_players_on_name"
  add_index "players", ["prompt_rating"], name: "index_players_on_prompt_rating"
  add_index "players", ["prompts_answered"], name: "index_players_on_prompts_answered"
  add_index "players", ["prompts_won"], name: "index_players_on_prompts_won"
  add_index "players", ["rating"], name: "index_players_on_rating"
  add_index "players", ["votes_received"], name: "index_players_on_votes_received"

  create_table "prompt_type_ratings", force: :cascade do |t|
    t.integer  "player_id"
    t.string   "prompt_type"
    t.integer  "value"
    t.integer  "total"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  add_index "prompt_type_ratings", ["player_id", "prompt_type"], name: "index_prompt_type_ratings_on_player_id_and_prompt_type", unique: true
  add_index "prompt_type_ratings", ["player_id"], name: "index_prompt_type_ratings_on_player_id"
  add_index "prompt_type_ratings", ["prompt_type"], name: "index_prompt_type_ratings_on_prompt_type"

  create_table "prompts", force: :cascade do |t|
    t.string   "prompt_type"
    t.string   "inline_url"
    t.string   "full_url"
    t.text     "content"
    t.integer  "game_id"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.string   "guid"
    t.datetime "expires"
  end

  add_index "prompts", ["expires"], name: "index_prompts_on_expires"
  add_index "prompts", ["game_id"], name: "index_prompts_on_game_id"
  add_index "prompts", ["guid"], name: "index_prompts_on_guid"
  add_index "prompts", ["prompt_type"], name: "index_prompts_on_prompt_type"

  create_table "sessions", force: :cascade do |t|
    t.integer  "player_id"
    t.string   "token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "sessions", ["player_id"], name: "index_sessions_on_player_id"

  create_table "track_revisions", force: :cascade do |t|
    t.integer  "track_id"
    t.string   "name"
    t.text     "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "track_revisions", ["name"], name: "index_track_revisions_on_name"
  add_index "track_revisions", ["track_id"], name: "index_track_revisions_on_track_id"

  create_table "tracks", force: :cascade do |t|
    t.integer  "creator_id"
    t.integer  "published_revision_id"
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
  end

  add_index "tracks", ["creator_id"], name: "index_tracks_on_creator_id"
  add_index "tracks", ["published_revision_id"], name: "index_tracks_on_published_revision_id"

end
