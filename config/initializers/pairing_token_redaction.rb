# A pairing URL is the whole credential: it signs an iPad in as a child, it never expires, and
# only a revoke retires it. The token is a path segment rather than a parameter, so
# `filter_parameters` never sees it, and both the logs and the traces this app emits leave the
# house and are kept for weeks. Redact the path at the one place each of them reads it from.
module PairingTokenRedaction
  FILTERED = "/p/[FILTERED]"
  TOKEN_IN_PATH = %r{\A/p/[^/?]+}

  # Which of the two the Rack instrumentation writes depends on OTEL_SEMCONV_STABILITY_OPT_IN,
  # so both are rewritten rather than one guessed at.
  SPAN_PATH_ATTRIBUTES = %w[http.target url.path].freeze

  def self.scrub(path) = path&.sub(TOKEN_IN_PATH, FILTERED)

  # Every path Rails logs — the request line, the completed-action payload, an exception
  # report — is this one method.
  module FilteredPath
    def filtered_path = PairingTokenRedaction.scrub(super)
  end

  # The Rack instrumentation sets the path when it starts the span, so the rewrite lands
  # before anything can export it.
  class SpanProcessor
    def on_start(span, _parent_context)
      SPAN_PATH_ATTRIBUTES.each do |attribute|
        path = span.attributes[attribute]
        span.set_attribute attribute, PairingTokenRedaction.scrub(path) if path
      end
    end

    def on_finish(span) = nil

    def force_flush(timeout: nil) = OpenTelemetry::SDK::Trace::Export::SUCCESS

    def shutdown(timeout: nil) = OpenTelemetry::SDK::Trace::Export::SUCCESS
  end
end

ActiveSupport.on_load(:action_dispatch_request) { prepend PairingTokenRedaction::FilteredPath }

# The SDK is configured by the opentelemetry initializer, which loads first. Without an OTLP
# endpoint it is never configured and the no-op provider takes no processors.
if OpenTelemetry.tracer_provider.is_a? OpenTelemetry::SDK::Trace::TracerProvider
  OpenTelemetry.tracer_provider.add_span_processor PairingTokenRedaction::SpanProcessor.new
end
