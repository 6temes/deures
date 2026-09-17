class CreateHouseholds < ActiveRecord::Migration[8.1]
  def change
    create_table :households do |t|
      t.string :time_zone, null: false, default: "Asia/Tokyo"

      t.timestamps
    end
  end
end
