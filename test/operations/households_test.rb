require "test_helper"

class HouseholdsTest < ActiveSupport::TestCase
  # 23:30 UTC on the 13th is 08:30 Tokyo on the 14th, the date the fixtures call today.
  setup { travel_to Time.utc(2026, 9, 13, 23, 30) }

  test "changing the household time zone while a study day is open leaves that day's date and queue alone" do
    day = study_days(:pau_today)
    queue = day.queue_items.order(:sort_key).pluck :id

    out, = capture_io { Ops::Households::SetTimeZone.call zone: "America/Los_Angeles" }

    assert_equal "America/Los_Angeles", Household.instance.time_zone
    assert_equal Date.new(2026, 9, 14), day.reload.study_date
    assert_equal queue, day.queue_items.order(:sort_key).pluck(:id)
    assert_equal Date.new(2026, 9, 13), Household.with_zone { Date.current }
    assert_includes out, "Asia/Tokyo → America/Los_Angeles"
  end

  test "a time zone Rails does not know is refused" do
    refusal = assert_raises Ops::Base::Refused do
      capture_io { Ops::Households::SetTimeZone.call zone: "Mars/Olympus" }
    end

    assert_includes refusal.message, "Mars/Olympus"
    assert_equal "Asia/Tokyo", Household.instance.time_zone
  end

  test "setting the holiday country changes which dates are free" do
    out, = capture_io { Ops::Households::SetHolidayCountry.call country: "es" }

    assert_equal "es", Household.instance.holiday_country
    assert Household.instance.free_day?(Date.new(2026, 10, 12))
    assert_includes out, "jp → es"
  end

  test "a holiday country the holidays gem does not know is refused" do
    refusal = assert_raises Ops::Base::Refused do
      capture_io { Ops::Households::SetHolidayCountry.call country: "atlantis" }
    end

    assert_includes refusal.message, "atlantis"
    assert_equal "jp", Household.instance.holiday_country
  end
end
