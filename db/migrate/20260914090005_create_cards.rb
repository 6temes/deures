class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards do |t|
      t.references :deck, null: false, foreign_key: true, index: false
      t.integer :position, null: false
      t.text :prompt, null: false
      t.string :prompt_key, null: false
      t.json :accepted_answers, null: false
      t.json :accepted_keys, null: false
      t.string :content_digest, null: false
      t.datetime :retired_at

      t.timestamps

      t.index [:deck_id, :position]
      t.index [:deck_id, :prompt_key], unique: true, where: "retired_at IS NULL"
    end
  end
end
