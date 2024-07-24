# frozen_string_literal: true

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

ActiveRecord::Schema[7.1].define(version: 20_240_723_045_728) do
  create_schema 'unmnemonic_devices'
  create_schema 'waydowntown'

  # These are extensions that must be enabled in order to support this database
  enable_extension 'pg_trgm'
  enable_extension 'plpgsql'

  create_table 'answers', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.string 'answer', limit: 255
    t.uuid 'game_id'
    t.datetime 'inserted_at', precision: 0, null: false
    t.datetime 'updated_at', precision: 0, null: false
  end

  create_table 'games', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.uuid 'incarnation_id'
    t.datetime 'inserted_at', precision: 0, null: false
    t.datetime 'updated_at', precision: 0, null: false
    t.uuid 'winner_answer_id'
  end

  create_table 'incarnations', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.string 'concept', limit: 255
    t.string 'mask', limit: 255
    t.string 'answer', limit: 255
    t.datetime 'inserted_at', precision: 0, null: false
    t.datetime 'updated_at', precision: 0, null: false
    t.uuid 'region_id', null: false
  end

  create_table 'messages', id: :uuid, default: nil, force: :cascade do |t|
    t.string 'subject', limit: 255
    t.text 'content'
    t.boolean 'ready', default: false
    t.date 'postmarked_at'
    t.datetime 'inserted_at', precision: 0, null: false
    t.datetime 'updated_at', precision: 0, null: false
    t.text 'rendered_content'
    t.boolean 'show_team'
    t.string 'from_name', limit: 255
    t.string 'from_address', limit: 255
  end

  create_table 'regions', id: :uuid, default: -> { 'gen_random_uuid()' }, force: :cascade do |t|
    t.string 'name', limit: 255
    t.text 'description'
    t.uuid 'parent_id'
  end

  create_table 'teams', id: :uuid, default: nil, force: :cascade do |t|
    t.text 'name'
    t.integer 'risk_aversion'
    t.text 'notes'
    t.datetime 'inserted_at', precision: 0, null: false
    t.datetime 'updated_at', precision: 0, null: false
    t.string 'voicepass', limit: 255
    t.integer 'listens', default: 0
    t.virtual 'name_truncated', type: :string, limit: 53,
                                as: "\nCASE\n    WHEN (length(name) > 50) THEN (\"substring\"(name, 1, (50 - \"position\"(reverse(\"substring\"(name, 1, 50)), ' '::text))) || '…'::text)\n    ELSE name\nEND", stored: true
  end

  create_table 'user_identities', id: :uuid, default: nil, force: :cascade do |t|
    t.string 'provider', limit: 255, null: false
    t.string 'uid', limit: 255, null: false
    t.uuid 'user_id'
    t.datetime 'inserted_at', precision: 0, null: false
    t.datetime 'updated_at', precision: 0, null: false
    t.index %w[uid provider], name: 'user_identities_uid_provider_index', unique: true
  end

  create_table 'users', id: :uuid, default: nil, force: :cascade do |t|
    t.string 'email', limit: 255, null: false
    t.string 'password_hash', limit: 255
    t.datetime 'inserted_at', precision: 0, null: false
    t.datetime 'updated_at', precision: 0, null: false
    t.boolean 'admin'
    t.text 'team_emails'
    t.text 'proposed_team_name'
    t.integer 'risk_aversion'
    t.text 'accessibility'
    t.string 'recovery_hash', limit: 255
    t.text 'comments'
    t.text 'source'
    t.boolean 'attending'
    t.string 'voicepass', limit: 255
    t.integer 'remembered', default: 0
    t.uuid 'team_id'
    t.string 'invitation_token', limit: 255
    t.datetime 'invitation_accepted_at', precision: 0
    t.uuid 'invited_by_id'
    t.index ['email'], name: 'users_email_index', unique: true
    t.index ['invitation_token'], name: 'users_invitation_token_index', unique: true
  end

  add_foreign_key 'answers', 'games', name: 'answers_game_id_fkey'
  add_foreign_key 'games', 'answers', column: 'winner_answer_id', name: 'games_winner_answer_id_fkey',
                                      on_delete: :nullify
  add_foreign_key 'games', 'incarnations', name: 'games_incarnation_id_fkey'
  add_foreign_key 'incarnations', 'regions', name: 'incarnations_region_id_fkey', on_delete: :nullify
  add_foreign_key 'regions', 'regions', column: 'parent_id', name: 'regions_parent_id_fkey', on_delete: :nullify
  add_foreign_key 'user_identities', 'users', name: 'user_identities_user_id_fkey'
  add_foreign_key 'users', 'teams', name: 'users_team_id_fkey', on_delete: :nullify
  add_foreign_key 'users', 'users', column: 'invited_by_id', name: 'users_invited_by_id_fkey'
end
