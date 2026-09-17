module Ops
  module Households
    class SetTimeZone < Ops::Base
      operation name: "household.set_time_zone",
        description: "Set the time zone every study date in the app is the calendar date in.",
        example: %(Ops::Households::SetTimeZone.call zone: "Europe/Madrid")

      def initialize(zone:)
        @zone = zone
      end

      def perform
        refuse! %(no time zone called "#{@zone}" — pass a name Rails knows, such as "Asia/Tokyo") unless ActiveSupport::TimeZone[@zone]

        household = Household.instance
        before = household.time_zone
        household.update! time_zone: @zone

        # A day that is already open keeps the date it was opened with: this zone decides the
        # next study day, and nothing re-dates the one the children are answering.
        "household time zone #{before} → #{@zone}, where today is #{Time.use_zone(@zone) { Date.current }}"
      end
    end
  end
end
