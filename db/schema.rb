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

ActiveRecord::Schema[8.1].define(version: 2026_09_22_200000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "attempts", force: :cascade do |t|
    t.json "accepted_keys", null: false
    t.text "answer", null: false
    t.string "answer_key", null: false
    t.integer "attempt_index", null: false
    t.integer "card_id"
    t.integer "child_id", null: false
    t.datetime "created_at", null: false
    t.text "prompt", null: false
    t.float "seconds_to_answer", null: false
    t.string "showing_token", null: false
    t.date "study_date", null: false
    t.datetime "updated_at", null: false
    t.string "verdict", null: false
    t.index ["card_id"], name: "index_attempts_on_card_id"
    t.index ["child_id", "card_id", "study_date"], name: "index_attempts_on_lapses", where: "attempt_index = 1 AND verdict = 'wrong'"
    t.index ["child_id", "study_date"], name: "index_attempts_on_child_id_and_study_date"
    t.index ["showing_token"], name: "index_attempts_on_showing_token", unique: true
    t.check_constraint "attempt_index >= 1", name: "attempt_index_is_positive"
    t.check_constraint "seconds_to_answer >= 0", name: "seconds_to_answer_is_not_negative"
  end

  create_table "card_progresses", force: :cascade do |t|
    t.integer "card_id", null: false
    t.integer "child_id", null: false
    t.datetime "created_at", null: false
    t.date "due_on"
    t.date "last_answered_on"
    t.date "parked_on"
    t.integer "rung", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["card_id"], name: "index_card_progresses_on_card_id"
    t.index ["child_id", "card_id"], name: "index_card_progresses_on_child_id_and_card_id", unique: true
    t.index ["child_id", "due_on"], name: "index_card_progresses_on_child_id_and_due_on", where: "due_on IS NOT NULL"
    t.check_constraint "rung >= 0 AND rung <= 6", name: "rung_is_on_the_ladder"
  end

  create_table "cards", force: :cascade do |t|
    t.json "accepted_answers", null: false
    t.json "accepted_keys", null: false
    t.string "content_digest", null: false
    t.datetime "created_at", null: false
    t.integer "deck_id", null: false
    t.integer "position", null: false
    t.text "prompt", null: false
    t.string "prompt_key", null: false
    t.datetime "retired_at"
    t.datetime "updated_at", null: false
    t.index ["deck_id", "position"], name: "index_cards_on_deck_id_and_position"
    t.index ["deck_id", "prompt_key"], name: "index_cards_on_deck_id_and_prompt_key", unique: true, where: "retired_at IS NULL"
  end

  create_table "children", force: :cascade do |t|
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.date "created_on", null: false
    t.integer "light_day_threshold", default: 10, null: false
    t.string "name", null: false
    t.integer "new_card_cap", default: 5, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_children_on_name", unique: true
    t.check_constraint "light_day_threshold >= 1", name: "light_day_threshold_leaves_room"
    t.check_constraint "new_card_cap >= 0", name: "new_card_cap_is_not_negative"
  end

  create_table "deck_assignments", force: :cascade do |t|
    t.integer "child_id", null: false
    t.datetime "created_at", null: false
    t.integer "deck_id", null: false
    t.integer "position", null: false
    t.datetime "unassigned_at"
    t.datetime "updated_at", null: false
    t.index ["child_id", "deck_id"], name: "index_deck_assignments_on_child_id_and_deck_id", unique: true
    t.index ["deck_id"], name: "index_deck_assignments_on_deck_id"
  end

  create_table "decks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_decks_on_name", unique: true
  end

  create_table "devices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "forgotten_at"
    t.datetime "last_seen_at"
    t.integer "pairing_link_id", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["pairing_link_id"], name: "index_devices_on_pairing_link_id"
    t.index ["token_digest"], name: "index_devices_on_token_digest", unique: true
  end

  create_table "households", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "time_zone", default: "Asia/Tokyo", null: false
    t.datetime "updated_at", null: false
  end

  create_table "informant_error_groups", force: :cascade do |t|
    t.string "controller_action"
    t.datetime "created_at", null: false
    t.integer "duplicate_of_id"
    t.string "error_class", null: false
    t.string "fingerprint", null: false
    t.string "first_backtrace_line"
    t.datetime "first_seen_at", null: false
    t.datetime "fix_deployed_at"
    t.string "fix_pr_url"
    t.string "fix_sha"
    t.string "job_class"
    t.datetime "last_notified_at"
    t.datetime "last_occurrence_stored_at"
    t.datetime "last_seen_at", null: false
    t.text "message"
    t.text "notes"
    t.string "original_sha"
    t.datetime "resolved_at"
    t.string "severity", default: "error"
    t.string "status", default: "unresolved", null: false
    t.integer "total_occurrences", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["duplicate_of_id"], name: "index_informant_error_groups_on_duplicate_of_id"
    t.index ["error_class"], name: "index_informant_error_groups_on_error_class"
    t.index ["fingerprint"], name: "index_informant_error_groups_on_fingerprint", unique: true
    t.index ["status", "last_seen_at"], name: "index_informant_error_groups_on_status_and_last_seen_at"
    t.index ["status", "original_sha"], name: "index_informant_error_groups_on_status_and_original_sha"
    t.index ["status", "resolved_at"], name: "index_informant_error_groups_on_status_and_resolved_at"
    t.index ["status", "total_occurrences"], name: "index_informant_error_groups_on_status_and_total_occurrences"
    t.index ["status", "updated_at"], name: "index_informant_error_groups_on_status_and_updated_at"
    t.check_constraint "duplicate_of_id IS NULL OR duplicate_of_id != id", name: "check_no_self_duplicate"
  end

  create_table "informant_occurrences", force: :cascade do |t|
    t.json "backtrace"
    t.json "breadcrumbs"
    t.datetime "created_at", null: false
    t.json "custom_context"
    t.json "environment_context"
    t.integer "error_group_id", null: false
    t.json "exception_chain"
    t.string "git_sha"
    t.json "request_context"
    t.datetime "updated_at", null: false
    t.json "user_context"
    t.index ["created_at"], name: "index_informant_occurrences_on_created_at"
    t.index ["error_group_id", "created_at"], name: "index_informant_occurrences_on_error_group_id_and_created_at"
    t.index ["error_group_id"], name: "index_informant_occurrences_on_error_group_id"
  end

  create_table "pairing_links", force: :cascade do |t|
    t.integer "child_id", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.datetime "updated_at", null: false
    t.index ["child_id"], name: "index_pairing_links_on_child_id"
  end

  create_table "queue_items", force: :cascade do |t|
    t.integer "card_id"
    t.datetime "cleared_at"
    t.string "cleared_reason"
    t.datetime "created_at", null: false
    t.datetime "last_wrong_at"
    t.string "showing_token"
    t.json "shown_accepted_keys"
    t.datetime "shown_at"
    t.text "shown_prompt"
    t.integer "sort_key", null: false
    t.string "source", null: false
    t.integer "study_day_id", null: false
    t.datetime "updated_at", null: false
    t.integer "wrong_count", default: 0, null: false
    t.index ["card_id"], name: "index_queue_items_on_card_id"
    t.index ["showing_token"], name: "index_queue_items_on_showing_token", unique: true
    t.index ["study_day_id", "card_id"], name: "index_queue_items_on_study_day_id_and_card_id", unique: true
    t.check_constraint "wrong_count >= 0", name: "wrong_count_is_not_negative"
  end

  create_table "study_days", force: :cascade do |t|
    t.integer "child_id", null: false
    t.datetime "created_at", null: false
    t.datetime "done_at"
    t.datetime "done_seen_at"
    t.integer "due_count_at_open"
    t.string "excuse_reason"
    t.datetime "excused_at"
    t.datetime "first_opened_at"
    t.integer "new_count_at_open"
    t.date "study_date", null: false
    t.datetime "updated_at", null: false
    t.index ["child_id", "study_date"], name: "index_study_days_on_child_id_and_study_date", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "attempts", "cards"
  add_foreign_key "attempts", "children"
  add_foreign_key "card_progresses", "cards"
  add_foreign_key "card_progresses", "children"
  add_foreign_key "cards", "decks"
  add_foreign_key "deck_assignments", "children"
  add_foreign_key "deck_assignments", "decks"
  add_foreign_key "devices", "pairing_links"
  add_foreign_key "informant_error_groups", "informant_error_groups", column: "duplicate_of_id"
  add_foreign_key "informant_occurrences", "informant_error_groups", column: "error_group_id"
  add_foreign_key "pairing_links", "children"
  add_foreign_key "queue_items", "cards", on_delete: :nullify
  add_foreign_key "queue_items", "study_days"
  add_foreign_key "study_days", "children"
end
