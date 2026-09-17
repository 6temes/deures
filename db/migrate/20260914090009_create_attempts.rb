class CreateAttempts < ActiveRecord::Migration[8.1]
  def change
    create_table :attempts do |t|
      t.references :child, null: false, foreign_key: true, index: false
      t.references :card, foreign_key: true
      t.date :study_date, null: false
      t.text :prompt, null: false
      t.json :accepted_keys, null: false
      t.text :answer, null: false
      t.string :answer_key, null: false
      t.string :verdict, null: false
      t.float :seconds_to_answer, null: false
      t.integer :attempt_index, null: false
      t.string :showing_token, null: false

      t.timestamps

      t.index :showing_token, unique: true
      t.index [:child_id, :study_date]
      t.index [:child_id, :card_id, :study_date],
        where: "attempt_index = 1 AND verdict = 'wrong'",
        name: "index_attempts_on_lapses"

      t.check_constraint "attempt_index >= 1", name: "attempt_index_is_positive"
      t.check_constraint "seconds_to_answer >= 0", name: "seconds_to_answer_is_not_negative"
    end
  end
end
