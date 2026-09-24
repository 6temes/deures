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
class Household < ApplicationRecord
  validates :holiday_country, :time_zone, presence: true
  validate :holiday_country_is_known
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

  def free_day?(date)
    date.on_weekend? || Holidays.on(date, holiday_region).any?
  end

  def free_dates(range)
    holidays = Holidays.between(range.begin, range.end, holiday_region).pluck(:date).to_set
    range.select { it.on_weekend? || holidays.include?(it) }
  end

  private

  def holiday_region
    holiday_country.to_sym
  end

  def holiday_country_is_known
    return if holiday_country.blank? || Holidays.available_regions.include?(holiday_region)

    errors.add :holiday_country, "is not a region the holidays gem knows"
  end

  def time_zone_is_known
    return if time_zone.blank? || ActiveSupport::TimeZone[time_zone]

    errors.add :time_zone, "is not a time zone Rails knows"
  end

  def household_is_a_singleton
    return unless Household.exists?

    errors.add :base, "there is already a household; the time zone is set on that row"
  end
end
