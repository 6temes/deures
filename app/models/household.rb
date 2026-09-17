# == Schema Information
#
# Table name: households
#
#  id         :integer          not null, primary key
#  time_zone  :string           default("Asia/Tokyo"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class Household < ApplicationRecord
  validates :time_zone, presence: true
  validate :time_zone_is_known
  validate :household_is_a_singleton, on: :create

  def self.instance
    first!
  end

  # Every study date in the app is `Date.current` inside this block, and nowhere else.
  # SQLite has no session time zone, so `date('now')` and `Date.today` are UTC and name
  # yesterday for the first nine hours of every Tokyo day.
  def self.with_zone(&)
    Time.use_zone instance.time_zone, &
  end

  private

  def time_zone_is_known
    return if time_zone.blank? || ActiveSupport::TimeZone[time_zone]

    errors.add :time_zone, "is not a time zone Rails knows"
  end

  def household_is_a_singleton
    return unless Household.exists?

    errors.add :base, "there is already a household; the time zone is set on that row"
  end
end
