require "test_helper"

# == Schema Information
#
# Table name: households
#
#  id         :integer          not null, primary key
#  time_zone  :string           default("Asia/Tokyo"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
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

  test "a second household is invalid" do
    assert_not Household.new(time_zone: "Asia/Tokyo").valid?
  end
end
