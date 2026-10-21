Rails.application.routes.draw do
  mount RailsInformant::Engine => "/informant"

  if Rails.env.development?
    # Hyperdrive's MCP endpoint runs arbitrary Ruby with no authentication, and the gem
    # itself only rejects foreign browser Origins. A tunnel delivers requests from
    # 127.0.0.1 too, so this reads the raw socket address and Host header (request.host
    # and remote_ip trust X-Forwarded-*) and refuses anything a proxy forwarded.
    forwarded = %w[HTTP_FORWARDED HTTP_X_FORWARDED_FOR HTTP_X_FORWARDED_HOST HTTP_CF_CONNECTING_IP]
    direct_loopback = lambda do |request|
      request.remote_addr.in?(%w[127.0.0.1 ::1]) &&
        request.get_header("HTTP_HOST").to_s.sub(/:\d+\z/, "").in?(%w[localhost 127.0.0.1 [::1]]) &&
        forwarded.none? { request.has_header? it }
    end
    constraints direct_loopback do
      mount Rails::Hyperdrive::Engine => "/_hyperdrive"
    end
  end

  root "studies#show"

  post "answers" => "answers#create"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  get "p" => "pairings#show", :as => :pairing

  # The path is a literal filename, not a token, but Rails still appends an optional (.:format)
  # after it unless format is turned off — so "manifest.webmanifest.json" would otherwise also
  # route, rendered as JSON, when it should 404 like any other unrecognized path.
  get "p/manifest.webmanifest" => "pairings#manifest", :as => :pairing_manifest, :format => false
end
