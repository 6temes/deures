# A pairing URL is the whole credential: it signs an iPad in as a child, it never expires, and
# only a revoke retires it. The token is a path segment rather than a parameter, so
# `filter_parameters` never sees it, and the logs, the traces and the errors this app records all
# leave the house and are kept for weeks. Redact the path at the one place each of them reads it
# from.
module PairingTokenRedaction
  FILTERED = "/p/[FILTERED]"

  # A path as Rails logs it, or the absolute URL informant records from the request. In both the
  # token is the first segment after `/p/`; `\K` drops whatever origin precedes it from the match,
  # so only the token is replaced.
  TOKEN_IN_PATH = %r{\A(?:\w+://[^/]+)?\K/p/[^/?]+}

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

  # Informant persists what it captures into this app's own primary database, which Litestream
  # replicates off the house, and it reads the request path straight from the Rack env rather
  # than through `filtered_path`. Its `before_record` hook runs before the occurrence's request
  # context is built and cannot reach it, so the two readers are wrapped instead.
  module Informant
    # The absolute URL recorded on every occurrence. The gem's own filtering covers the query
    # string only.
    module FilteredUrl
      def filtered_url(url) = PairingTokenRedaction.scrub(super)
    end

    # The path the gem hands its before_record callbacks.
    module EventRequestPath
      def request_path = PairingTokenRedaction.scrub(super)
    end
  end
end

ActiveSupport.on_load(:action_dispatch_request) { prepend PairingTokenRedaction::FilteredPath }

RailsInformant::ContextBuilder.singleton_class.prepend PairingTokenRedaction::Informant::FilteredUrl
RailsInformant::Event.prepend PairingTokenRedaction::Informant::EventRequestPath

# Registered after every initializer rather than at load: the SDK is configured by another
# initializer, and leaning on the two filenames sorting in the right order would let a rename
# switch the redaction off while tracing carried on. Without an OTLP endpoint the SDK is never
# configured and the no-op provider takes no processors.
Rails.application.config.after_initialize do
  if OpenTelemetry.tracer_provider.is_a? OpenTelemetry::SDK::Trace::TracerProvider
    OpenTelemetry.tracer_provider.add_span_processor PairingTokenRedaction::SpanProcessor.new
  end
end
