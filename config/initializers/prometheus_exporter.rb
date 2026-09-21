# The collector runs as a Kamal accessory rather than in this process, so that a deploy can
# start the new container without the old one still holding the metrics port.
if ENV["PROMETHEUS_COLLECTOR_HOST"].present? && !Rails.env.test?
  require "prometheus_exporter/client"
  require "prometheus_exporter/instrumentation"
  require "prometheus_exporter/middleware"

  PrometheusExporter::Client.default = PrometheusExporter::Client.new(
    host: ENV["PROMETHEUS_COLLECTOR_HOST"],
    port: 9394
  )

  # The health check and the assets would otherwise dominate the throughput count and flatten
  # the response-time histogram the alerts read.
  class FilteredPrometheusMiddleware < PrometheusExporter::Middleware
    SKIP_PATHS = %w[/up /assets].freeze

    def call(env)
      if SKIP_PATHS.any? { env["PATH_INFO"].start_with? it }
        @app.call env
      else
        super
      end
    end
  end

  Rails.application.middleware.unshift FilteredPrometheusMiddleware
end
