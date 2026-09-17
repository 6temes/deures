class CreateChildren < ActiveRecord::Migration[8.1]
  def change
    create_table :children do |t|
      t.string :name, null: false
      t.string :color, null: false
      t.integer :light_day_threshold, null: false, default: 10
      t.integer :new_card_cap, null: false, default: 5
      t.date :created_on, null: false

      t.timestamps

      t.index :name, unique: true

      t.check_constraint "light_day_threshold >= 1", name: "light_day_threshold_leaves_room"
      t.check_constraint "new_card_cap >= 0", name: "new_card_cap_is_not_negative"
    end
  end
end
