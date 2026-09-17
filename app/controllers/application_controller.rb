class ApplicationController < ActionController::Base
  include Authentication

  # The one place a request enters the household's time zone. An operation enters it for itself,
  # because an around_action does not run under `bin/rails runner`.
  around_action :in_household_zone

  stale_when_importmap_changes

  private

  def in_household_zone(&)
    Household.with_zone(&)
  end
end
