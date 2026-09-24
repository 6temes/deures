Rails.application.routes.draw do
  mount RailsInformant::Engine => "/informant"

  root "studies#show"

  post "answers" => "answers#create"

  resource :day, only: :show

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  get "p" => "pairings#show", :as => :pairing

  # The path is a literal filename, not a token, but Rails still appends an optional (.:format)
  # after it unless format is turned off — so "manifest.webmanifest.json" would otherwise also
  # route, rendered as JSON, when it should 404 like any other unrecognized path.
  get "p/manifest.webmanifest" => "pairings#manifest", :as => :pairing_manifest, :format => false

  get ".well-known/apple-app-site-association" => "well_knowns#apple_app_site_association", :format => false
end
