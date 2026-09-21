require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = {"cache-control" => "public, max-age=#{1.year.to_i}"}

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  config.ssl_options = {redirect: {exclude: ->(request) { request.path == "/up" }}}

  # Log to stdout as JSON, so a line arrives at the collector as fields rather than as a
  # sentence something downstream has to parse back apart.
  config.rails_semantic_logger.appenders do |appenders|
    appenders.add io: $stdout, formatter: :json
  end

  # The hash form names each tag, so the trace ids arrive as their own fields and a log line
  # can be opened as the trace it belongs to.
  config.log_tags = {
    request_id: :request_id,
    span_id: ->(_request) { OpenTelemetry::Trace.current_span.context.hex_span_id if OpenTelemetry::Trace.current_span.context.valid? },
    trace_id: ->(_request) { OpenTelemetry::Trace.current_span.context.hex_trace_id if OpenTelemetry::Trace.current_span.context.valid? }
  }

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = {database: {writing: :queue}}

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]

  # Enable DNS rebinding protection. The app answers on exactly one hostname.
  config.hosts = [ENV.fetch("APP_HOST", "study.example.com")]
  config.host_authorization = {exclude: ->(request) { request.path == "/up" }}
end
