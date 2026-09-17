class CreateCardProgresses < ActiveRecord::Migration[8.1]
  def change
    create_table :card_progresses do |t|
      t.references :child, null: false, foreign_key: true, index: false
      t.references :card, null: false, foreign_key: true
      t.integer :rung, null: false, default: 0
      t.date :due_on
      t.date :parked_on
      t.date :last_answered_on

      t.timestamps

      t.index [:child_id, :card_id], unique: true
      t.index [:child_id, :due_on], where: "due_on IS NOT NULL"

      # A rung is bounded by CardProgress::INTERVALS, so the 6 here and that array move together.
      t.check_constraint "rung >= 0 AND rung <= 6", name: "rung_is_on_the_ladder"
    end
  end
end
