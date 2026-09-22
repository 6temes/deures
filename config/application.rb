require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Deures
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Nor does anything here serve or receive a blob over HTTP, and this app is open to the
    # internet with no gate in front of it, so the engine's upload and redirect routes would be
    # a surface with no caller behind it.
    config.active_storage.draw_routes = false

    # A request to an unrouted path under /p/ raises a routing error whose message quotes the
    # path, and a rescued response is logged as that message rather than through the filtered
    # path everything else reads. The pairing token is the whole credential, so the 404 goes:
    # the request line above it already records the path, scrubbed, and its status.
    config.action_dispatch.log_rescued_responses = false

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # Boot default only. The household time zone that decides a study day is a row
    # on Household, because the agent changes it at runtime and this setting is read at boot.
    config.time_zone = "Tokyo"

    # The console's own help is IRB's, and IRB does not exist under `bin/rails runner`,
    # so `Ops.help` is the operation listing and this only mirrors it into the console.
    # Rails 8 has no Rails::ConsoleMethods, so a command class is the way in.
    console do
      require "irb/command"

      listing = Class.new(IRB::Command::Base) do
        category "Deures"
        description "List every agent operation, with a working example of each."

        def execute(*) = ::Ops.help
      end

      IRB::Command.register :ops, listing
    end
  end
end
