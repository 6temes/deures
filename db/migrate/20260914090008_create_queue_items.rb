class CreateQueueItems < ActiveRecord::Migration[8.1]
  def change
    create_table :queue_items do |t|
      t.references :study_day, null: false, foreign_key: true, index: false
      t.references :card, foreign_key: {on_delete: :nullify}
      t.integer :sort_key, null: false
      t.string :source, null: false
      t.integer :wrong_count, null: false, default: 0
      t.string :showing_token
      t.datetime :shown_at
      t.text :shown_prompt
      t.json :shown_accepted_keys
      t.datetime :last_wrong_at
      t.datetime :cleared_at
      t.string :cleared_reason

      t.timestamps

      t.index [:study_day_id, :card_id], unique: true
      t.index :showing_token, unique: true

      t.check_constraint "wrong_count >= 0", name: "wrong_count_is_not_negative"
    end
  end
end
