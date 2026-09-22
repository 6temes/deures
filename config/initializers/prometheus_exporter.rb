# The health check and the assets would otherwise dominate the throughput count and flatten the
# response-time histogram the alerts read. The decision sits outside the guard below so that it
# is exercised by the suite, which never has a collector.
module PrometheusPathFilter
  SKIP_PATHS = %w[/up /assets].freeze

  def self.skip?(path) = SKIP_PATHS.any? { path.start_with? it }
end

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

  class FilteredPrometheusMiddleware < PrometheusExporter::Middleware
    def call(env)
      if PrometheusPathFilter.skip? env["PATH_INFO"]
        @app.call env
      else
        super
      end
    end
  end

  Rails.application.middleware.unshift FilteredPrometheusMiddleware
end
