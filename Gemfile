source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3", ">= 8.1.3.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use sqlite3 as the database for Active Record
gem "sqlite3", ">= 2.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cable"
gem "solid_cache"
gem "solid_queue"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# json 3.0 made JSON.parse keyword-only, and Active Support 8.1.3.1 still passes its
# options positionally, which breaks every json column and every JSON request body.
gem "json", "~> 2.21"

# The pairing link is shown as a QR code in the console that issued it
# [https://github.com/whomwah/rqrcode_core]
gem "rqrcode_core"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Active Storage variants, through libvips. image_processing leaves the vips binding to an
# optional dependency, so ruby-vips is named too rather than left to resolve by luck.
gem "image_processing"
gem "ruby-vips"

# Prometheus metrics, reported to a collector running as a separate Kamal accessory
gem "prometheus_exporter"

# Error monitoring kept in this app's own database, read through its MCP server. Nobody is
# watching when a child's iPad hits a 500, so the app has to keep the record itself
# [https://github.com/6temes/rails-informant]
gem "rails-informant"

# Structured JSON logging to stdout, so a log line arrives at the collector as fields
# rather than as a line to be re-parsed [https://github.com/reidmorrison/rails_semantic_logger]
gem "rails_semantic_logger"

# OpenTelemetry tracing. The instrumentations are listed one by one rather than through a
# meta-gem so that nothing this app does not run gets loaded; action_mailer is absent because
# action_mailer/railtie is commented out in config/application.rb.
gem "opentelemetry-exporter-otlp"
gem "opentelemetry-instrumentation-action_pack"
gem "opentelemetry-instrumentation-action_view"
gem "opentelemetry-instrumentation-active_job"
gem "opentelemetry-instrumentation-active_support"
gem "opentelemetry-instrumentation-net_http"
gem "opentelemetry-instrumentation-rack"
gem "opentelemetry-sdk"

group :development, :test do
  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Finds a model validation with no database constraint behind it, which is the house rule
  # this app is built on [https://github.com/djezzzl/database_consistency]
  gem "database_consistency", require: false

  # Finds routes nothing reaches and actions nothing routes to
  # Loaded, not required: the rake task arrives through its railtie.
  gem "traceroute"

  # Lints the ERB templates the children's screens are built from [https://herb-tools.dev]
  gem "herb", require: false

  # Ruby styling with no configuration to argue about, plus the Rails cops
  # [https://github.com/standardrb/standard-rails]
  gem "standard", require: false
  gem "standard-rails", require: false
end

group :development do
  # Keeps the schema of each table in a comment at the top of its model, test, and fixture
  # [https://github.com/drwl/annotaterb]
  gem "annotaterb", require: false

  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"

  # Minitest 6 moved its own Mock and Object#stub out into this gem. It is not a second
  # mocking library: it is where `stub` lives now.
  gem "minitest-mock"

  gem "selenium-webdriver"
end
