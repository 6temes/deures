class CreateDeckAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :deck_assignments do |t|
      t.references :child, null: false, foreign_key: true, index: false
      t.references :deck, null: false, foreign_key: true
      t.integer :position, null: false
      t.datetime :unassigned_at

      t.timestamps

      t.index [:child_id, :deck_id], unique: true
    end
  end
end
