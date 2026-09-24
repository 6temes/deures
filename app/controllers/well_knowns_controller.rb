class WellKnownsController < ApplicationController
  allow_unauthenticated_access

  # The app ID comes from the environment because it carries the Team ID, which the source never
  # names. Without one there is no app to associate, and the file does not exist.
  def apple_app_site_association
    app_id = ENV["APPLE_APP_ID"]
    return head :not_found if app_id.blank?

    render json: {
      applinks: {
        details: [
          {appIDs: [app_id], components: [{"/" => pairing_path, "?" => {token: "?*"}}]}
        ]
      }
    }
  end
end
