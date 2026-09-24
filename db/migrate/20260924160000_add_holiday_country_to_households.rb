class AddHolidayCountryToHouseholds < ActiveRecord::Migration[8.1]
  def change
    add_column :households, :holiday_country, :string, null: false, default: "jp"
  end
end
