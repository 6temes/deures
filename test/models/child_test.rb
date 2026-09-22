require "test_helper"

# == Schema Information
#
# Table name: children
#
#  id                  :integer          not null, primary key
#  color               :string           not null
#  created_on          :date             not null
#  light_day_threshold :integer          default(10), not null
#  name                :string           not null
#  new_card_cap        :integer          default(5), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_children_on_name  (name) UNIQUE
#
# Check Constraints
#
#  light_day_threshold_leaves_room  (light_day_threshold >= 1)
#  new_card_cap_is_not_negative     (new_card_cap >= 0)
#
class ChildTest < ActiveSupport::TestCase
  test "a child's devices are read from the child, without the link that introduced them" do
    sql = children(:pau).devices.to_sql

    assert_no_match(/pairing_links/, sql)
    assert_match(/"devices"\."child_id"/, sql)
  end

  test "a child whose color is not a palette name is invalid" do
    child = Child.new name: "Mar", color: "chartreuse", created_on: Date.new(2026, 9, 14)

    assert_not child.valid?
    assert child.errors[:color].any?
  end

  test "a palette color carries the hex the manifest and the icon need" do
    assert_equal Child::COLORS.fetch("blue"), children(:pau).color_hex
    assert_equal Child::COLORS_DARK.fetch("blue"), children(:pau).color_hex_dark
  end

  test "every palette color has a dark-ground sibling" do
    # The two constants are read by different code paths — the manifest and the icon filename
    # from one, the dark appearance from the other — so nothing else would notice a color added
    # to one and not the other until a child rendered on a dark iPad with no color at all.
    assert_equal Child::COLORS.keys, Child::COLORS_DARK.keys
  end

  test "a color outside the palette has no dark sibling to fetch" do
    assert_raises(KeyError) { Child.new(color: "chartreuse").color_hex_dark }
  end

  test "the light day threshold is at least one" do
    child = children(:pau)
    child.light_day_threshold = 0

    assert_not child.valid?
    assert child.errors[:light_day_threshold].any?
  end

  test "the new card cap cannot exceed the light day threshold" do
    child = children(:pau)
    child.new_card_cap = 11

    assert_not child.valid?
    assert child.errors[:new_card_cap].any?
  end

  test "a new card cap of zero is allowed" do
    child = children(:pau)
    child.new_card_cap = 0

    assert child.valid?
  end

  # The name is how every operation addresses a child, so two children answering to one name
  # would make half of them unreachable. Validated in Ruby and constrained in the database,
  # and this is the half a `Child.create!` typed at the console cannot walk past.
  test "the database refuses a second child of the same name" do
    assert_raises ActiveRecord::RecordNotUnique do
      Child.insert!({color: "pink", created_on: Date.current, name: children(:pau).name},
        record_timestamps: true)
    end
  end

  test "the database refuses a threshold below one" do
    assert_raises ActiveRecord::StatementInvalid do
      children(:pau).update_column :light_day_threshold, 0
    end
  end
end
