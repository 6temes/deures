# Tracing is only configured when an OTLP endpoint is set. Without one the SDK is never
# configured and every OTel call in the app is the API's no-op.
if ENV["OTEL_EXPORTER_OTLP_ENDPOINT"].present? && !defined?(Rails::Console)
  require "opentelemetry/sdk"
  require "opentelemetry/exporter/otlp"

  OpenTelemetry::SDK.configure do |c|
    c.service_name = "deures"
    c.service_version = ENV.fetch("GIT_SHA", "unknown")
    c.resource = OpenTelemetry::SDK::Resources::Resource.create("deployment.environment" => Rails.env.to_s)

    # Named one by one rather than through use_all, so that adding an instrumentation gem is
    # the only way a new instrumentation starts running. /up is the health check, which every
    # minute would otherwise be the busiest endpoint in the trace store.
    c.use "OpenTelemetry::Instrumentation::Rack", untraced_endpoints: ["/up"]
    c.use "OpenTelemetry::Instrumentation::ActionPack"
    c.use "OpenTelemetry::Instrumentation::ActionView"
    c.use "OpenTelemetry::Instrumentation::ActiveJob"
    c.use "OpenTelemetry::Instrumentation::ActiveSupport"
    c.use "OpenTelemetry::Instrumentation::Net::HTTP"
  end
end
