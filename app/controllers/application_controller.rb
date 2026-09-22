class ApplicationController < ActionController::Base
  include Authentication

  # Every screen is wordless and the users are children, so a browser that cannot run the app has
  # to fail where an adult will see it rather than render a blank or half-working screen. The app
  # already needs import maps and modern CSS, so anything this refuses was broken anyway.
  allow_browser versions: :modern

  # The one place a request enters the household's time zone. An operation enters it for itself,
  # because an around_action does not run under `bin/rails runner`.
  around_action :in_household_zone

  stale_when_importmap_changes

  private

  def in_household_zone(&)
    Household.with_zone(&)
  end
end
