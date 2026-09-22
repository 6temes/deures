# A pairing URL is the whole credential: it signs an iPad in as a child, it never expires, and
# only a revoke retires it. `filter_parameters` names `:token`, which covers the logs and the
# errors informant records, but opentelemetry-instrumentation-rack copies the query string into
# span attributes straight out of the Rack env without passing it through that filter, and the
# traces leave the house and are kept for weeks.
module PairingTokenRedaction
  FILTERED = "token=[FILTERED]"

  # `\b` refuses a parameter whose name merely ends in `token`, whose value is not this one.
  TOKEN_IN_QUERY = /\btoken=[^&]*/

  # `http.target` is path and query together and `url.query` is the query alone; which pair the
  # instrumentation writes depends on OTEL_SEMCONV_STABILITY_OPT_IN, so both are rewritten rather
  # than one guessed at. `url.path` carries no token and is left alone.
  SPAN_QUERY_ATTRIBUTES = %w[http.target url.query].freeze

  def self.scrub(query) = query&.sub(TOKEN_IN_QUERY, FILTERED)

  # The Rack instrumentation sets the attributes when it starts the span, so the rewrite lands
  # before anything can export it.
  class SpanProcessor
    def on_start(span, _parent_context)
      SPAN_QUERY_ATTRIBUTES.each do |attribute|
        value = span.attributes[attribute]
        span.set_attribute attribute, PairingTokenRedaction.scrub(value) if value
      end
    end

    def on_finish(span) = nil

    def force_flush(timeout: nil) = OpenTelemetry::SDK::Trace::Export::SUCCESS

    def shutdown(timeout: nil) = OpenTelemetry::SDK::Trace::Export::SUCCESS
  end
end

# Registered after every initializer rather than at load: the SDK is configured by another
# initializer, and leaning on the two filenames sorting in the right order would let a rename
# switch the redaction off while tracing carried on. Without an OTLP endpoint the SDK is never
# configured and the no-op provider takes no processors.
Rails.application.config.after_initialize do
  if OpenTelemetry.tracer_provider.is_a? OpenTelemetry::SDK::Trace::TracerProvider
    OpenTelemetry.tracer_provider.add_span_processor PairingTokenRedaction::SpanProcessor.new
  end
end
