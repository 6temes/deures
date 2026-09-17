class CreateStudyDays < ActiveRecord::Migration[8.1]
  def change
    create_table :study_days do |t|
      t.references :child, null: false, foreign_key: true, index: false
      t.date :study_date, null: false
      t.datetime :first_opened_at
      t.integer :due_count_at_open
      t.integer :new_count_at_open
      t.datetime :done_at
      t.datetime :done_seen_at
      t.datetime :excused_at
      t.string :excuse_reason

      t.timestamps

      t.index [:child_id, :study_date], unique: true
    end
  end
end
