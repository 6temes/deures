require "test_helper"

# == Schema Information
#
# Table name: households
#
#  id              :integer          not null, primary key
#  holiday_country :string           default("jp"), not null
#  time_zone       :string           default("Asia/Tokyo"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
class HouseholdTest < ActiveSupport::TestCase
  test "an unknown time zone is invalid" do
    household = households(:tokyo)
    household.time_zone = "Middle Earth"

    assert_not household.valid?
    assert household.errors[:time_zone].any?
  end

  test "a tzinfo identifier and a Rails zone name are both accepted" do
    household = households(:tokyo)

    household.time_zone = "Asia/Tokyo"
    assert household.valid?

    household.time_zone = "Tokyo"
    assert household.valid?
  end

  test "a holiday country the holidays gem does not know is invalid" do
    household = households(:tokyo)
    household.holiday_country = "atlantis"

    assert_not household.valid?
    assert household.errors[:holiday_country].any?
  end

  test "Saturday and Sunday are free" do
    household = households(:tokyo)

    assert household.free_day?(Date.new(2026, 9, 26))
    assert household.free_day?(Date.new(2026, 9, 27))
  end

  test "a weekday national holiday is free" do
    assert households(:tokyo).free_day?(Date.new(2026, 9, 23))
  end

  test "a substitute holiday is free" do
    assert households(:tokyo).free_day?(Date.new(2026, 5, 6))
  end

  test "an ordinary weekday in the summer break is a school day" do
    assert_not households(:tokyo).free_day?(Date.new(2026, 8, 4))
  end

  test "the holidays come from the household country" do
    household = households(:tokyo)
    household.holiday_country = "es"

    assert_not household.free_day?(Date.new(2026, 9, 23))
    assert household.free_day?(Date.new(2026, 10, 12))
  end

  test "the free dates across the New Year are the holiday and the weekend after it" do
    free = households(:tokyo).free_dates(Date.new(2026, 12, 28)..Date.new(2027, 1, 5))

    assert_equal [Date.new(2027, 1, 1), Date.new(2027, 1, 2), Date.new(2027, 1, 3)], free
  end

  test "a second household is invalid" do
    assert_not Household.new(time_zone: "Asia/Tokyo").valid?
  end
end
