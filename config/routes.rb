Rails.application.routes.draw do
  mount RailsInformant::Engine => "/informant"

  root "studies#show"

  post "answers" => "answers#create"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # An installed Home Screen icon replays the pairing path on every launch, so a token must never
  # be parsed as a format: with the format segment on, a token ending in a dot-something would
  # arrive truncated and the iPad would be signed out for good.
  constraints token: /[A-Za-z0-9_-]+/ do
    get "p/:token" => "pairings#show", :as => :pairing, :format => false
    get "p/:token/manifest.webmanifest" => "pairings#manifest", :as => :pairing_manifest, :format => false
    get "p/:token/icon-180.png" => "pairings#icon", :as => :pairing_icon, :format => false
    get "p/:token/icon-512.png" => "pairings#icon_512", :as => :pairing_icon_512, :format => false
  end
end
