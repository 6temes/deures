RailsInformant.configure do |config|
  config.capture_errors = !Rails.env.local?

  # `rails runner` is the whole administration surface here, and the operator driving an
  # operation reads the exception on their own terminal. The gem captures runner errors by
  # default because elsewhere runner backs cron; here it does not, as the recurring work in
  # config/recurring.yml goes through Solid Queue.
  config.capture_runner_errors = false

  # Required whenever capture is on: the engine refuses to boot a server without it.
  config.api_token = Rails.application.credentials.dig(:rails_informant, :api_token)
end
