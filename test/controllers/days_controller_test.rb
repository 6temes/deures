require "test_helper"

class DaysControllerTest < ActionDispatch::IntegrationTest
  # 23:30 UTC on the 13th is 08:30 Tokyo on Monday the 14th, which is the date the fixtures call
  # today. A UTC reading would name Sunday the 13th, which is free.
  setup do
    travel_to Time.utc(2026, 9, 13, 23, 30)
  end

  test "a paired device on a school day with no study record is told pending, and the day stays unopened" do
    pair_device_as children(:teo)

    assert_no_difference -> { StudyDay.count } do
      get day_path
    end

    assert_response :success
    assert_equal "pending", payload["state"]
  end

  test "a child with no deck is told pending, and the day is neither opened nor settled (AE3)" do
    child = Child.create! name: "Mar", color: "pink", created_on: Date.new(2026, 9, 1)
    pair_device_as child

    get day_path

    assert_equal "pending", payload["state"]
    assert_empty child.study_days
  end

  test "an opened day with cards left is pending, and asking does not touch it" do
    pair_device_as children(:pau)

    assert_no_changes -> { study_days(:pau_today).reload.attributes } do
      get day_path
    end

    assert_equal "pending", payload["state"]
  end

  test "after the day settles it is done" do
    pair_device_as children(:pau)
    day = study_days(:pau_today)
    day.queue_items.each { it.clear! :correct }
    day.settle!

    get day_path

    assert_equal "done", payload["state"]
  end

  test "an excused day is excused (AE4)" do
    pair_device_as children(:pau)
    capture_io { Ops::Relief::Excuse.call child: "Pau", reason: "ill" }

    get day_path

    assert_equal "excused", payload["state"]
  end

  test "a Saturday is free, whatever the record holds" do
    travel_to Time.utc(2026, 9, 18, 23, 30)
    pair_device_as children(:pau)
    capture_io { Ops::Relief::Excuse.call child: "Pau", reason: "ill" }

    get day_path

    assert_equal "2026-09-19", payload["today"]
    assert_equal "free", payload["state"]
  end

  test "the payload names the paired child, the household's zone and today in that zone" do
    pair_device_as children(:pau)

    get day_path

    assert_equal children(:pau).id, payload["child_id"]
    assert_equal Household.instance.time_zone, payload["zone"]
    assert_equal "2026-09-14", payload["today"]
    assert_equal [], payload["windows"]
  end

  test "the free dates run from today through the fifty-ninth day after it, holidays included" do
    # Wednesday the 16th in Tokyo, so the last day of the range is Saturday 14 November and the
    # day after it is a Sunday: an off-by-one either way shows at both ends.
    travel_to Time.utc(2026, 9, 15, 23, 30)
    pair_device_as children(:pau)

    get day_path

    free = payload["free_dates"].map { Date.iso8601 it }
    assert_equal Date.new(2026, 9, 19), free.first
    assert_equal Date.new(2026, 11, 14), free.last
    assert_includes free, Date.new(2026, 9, 21), "Respect for the Aged Day"
    assert_includes free, Date.new(2026, 11, 3), "Culture Day"
    assert_not_includes free, Date.new(2026, 9, 18)
  end

  test "the free dates include today when today is free" do
    travel_to Time.utc(2026, 9, 18, 23, 30)
    pair_device_as children(:pau)

    get day_path

    assert_equal "2026-09-19", payload["free_dates"].first
  end

  test "a request with no device cookie gets 401 and JSON" do
    get day_path

    assert_response :unauthorized
    assert_equal "application/json", response.media_type
    assert_equal({"error" => "unpaired"}, payload)
  end

  test "a forgotten device gets 401" do
    pair_device_as(children(:pau)).forget!

    get day_path

    assert_response :unauthorized
    assert_equal({"error" => "unpaired"}, payload)
  end

  test "both answers carry no-store" do
    get day_path

    assert_equal "no-store", response.headers["Cache-Control"]

    pair_device_as children(:pau)
    get day_path

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  private

  def payload
    JSON.parse response.body
  end
end
