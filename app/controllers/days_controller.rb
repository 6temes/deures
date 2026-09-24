class DaysController < ApplicationController
  FREE_DATES_AHEAD = 59

  before_action :no_store

  def show
    return render json: {error: "unpaired"}, status: :unauthorized unless paired?

    child = Current.child
    household = Household.instance
    today = Date.current

    render json: {
      child_id: child.id,
      free_dates: household.free_dates(today..(today + FREE_DATES_AHEAD)),
      state: child.day_state(today),
      today:,
      windows: [],
      zone: household.time_zone
    }
  end
end
