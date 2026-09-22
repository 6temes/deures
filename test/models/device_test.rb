require "test_helper"

# == Schema Information
#
# Table name: devices
#
#  id           :integer          not null, primary key
#  forgotten_at :datetime
#  last_seen_at :datetime
#  token_digest :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  child_id     :integer          not null
#
# Indexes
#
#  index_devices_on_child_id      (child_id)
#  index_devices_on_token_digest  (token_digest) UNIQUE
#
# Foreign Keys
#
#  child_id  (child_id => children.id)
#
class DeviceTest < ActiveSupport::TestCase
  test "a paired iPad belongs to its child directly, with no pairing link in the path" do
    device = children(:pau).devices.create!

    assert_equal children(:pau), device.child
    assert_equal children(:pau), Device.find_by_token(device.plain_token).child
    assert_not_respond_to device, :pairing_link
  end

  test "forgetting one iPad signs that one out and leaves the child's other iPad working" do
    forgotten = children(:pau).devices.create!
    kept = children(:pau).devices.create!

    forgotten.forget!

    assert_nil Device.find_by_token(forgotten.plain_token)
    assert_equal children(:pau), Device.find_by_token(kept.plain_token).child
  end

  test "issues a plaintext token once and stores only its digest" do
    device = children(:pau).devices.create!

    assert_equal Digest::SHA256.hexdigest(device.plain_token), device.token_digest
    assert_not_includes device.attributes.values.map(&:to_s), device.plain_token
    assert_nil Device.find(device.id).plain_token
  end

  test "a child's second iPad gets a device and a token of its own" do
    first = children(:pau).devices.create!
    second = children(:pau).devices.create!

    assert_not_equal first, second
    assert_not_equal first.plain_token, second.plain_token
    assert_equal children(:pau), Device.find_by_token(first.plain_token).child
    assert_equal children(:pau), Device.find_by_token(second.plain_token).child
  end

  test "a forgotten device is not found by the token it holds, while the row still says whose iPad it was" do
    device = children(:pau).devices.create!
    token = device.plain_token

    device.forget!

    assert_nil Device.find_by_token(token)
    assert_equal children(:pau), device.child
  end

  test "an unknown or malformed token resolves to no device rather than raising" do
    children(:pau).devices.create!

    assert_nil Device.find_by_token("not-a-token")
    assert_nil Device.find_by_token("")
    assert_nil Device.find_by_token(nil)
  end

  test "last seen is stamped once and then left alone for an hour" do
    device = children(:pau).devices.create!

    travel_to Time.utc(2026, 9, 14, 3) do
      device.touch_last_seen

      assert_equal Time.utc(2026, 9, 14, 3), device.reload.last_seen_at
    end

    travel_to Time.utc(2026, 9, 14, 3, 30) do
      device.touch_last_seen

      assert_equal Time.utc(2026, 9, 14, 3), device.reload.last_seen_at
    end

    travel_to Time.utc(2026, 9, 14, 5) do
      device.touch_last_seen

      assert_equal Time.utc(2026, 9, 14, 5), device.reload.last_seen_at
    end
  end
end
