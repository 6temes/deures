require "test_helper"
require "opentelemetry/sdk"

# A pairing URL is the whole credential: it signs an iPad in as a child, it does not expire,
# and only a revoke retires it. Logs and traces both leave the house and are kept for weeks,
# so the token must not reach either.
class PairingTokenRedactionTest < ActionDispatch::IntegrationTest
  setup do
    @link = children(:pau).pairing_links.create!
    @token = @link.plain_token
    @events = SemanticLogger::Test::CaptureLogEvents.new
    SemanticLogger.add_appender appender: @events
  end

  teardown do
    SemanticLogger.remove_appender @events
  end

  test "the logged path of a pairing request carries no token" do
    get "/p/#{@token}"

    assert_equal "/p/[FILTERED]", logged_path
  end

  test "the logged path of a pairing icon carries no token" do
    get "/p/#{@token}/icon-180.png"

    assert_equal "/p/[FILTERED]/icon-180.png", logged_path
  end

  test "no log line anywhere carries the token" do
    get "/p/#{@token}"
    get "/p/#{@token}/manifest.webmanifest"
    SemanticLogger.flush

    assert_not_includes @events.to_h.to_s, @token
  end

  test "no log line carries the token when nothing under the pairing path is routed" do
    get "/p/#{@token}/nothing-is-routed-here"
    SemanticLogger.flush

    assert_not_includes @events.to_h.to_s, @token
  end

  test "the recorded span carries the scrubbed path under either semantic convention" do
    %w[http.target url.path].each do |attribute|
      span = recorded_span attribute => "/p/#{@token}/icon-512.png"

      assert_equal "/p/[FILTERED]/icon-512.png", span.attributes[attribute]
    end
  end

  test "the recorded span keeps a path that carries no token untouched" do
    span = recorded_span "url.path" => "/up"

    assert_equal "/up", span.attributes["url.path"]
  end

  private

  def logged_path
    SemanticLogger.flush
    event = @events.events.rfind { it.payload&.key? :path }
    assert event, "no log event carried a request path"
    event.payload[:path]
  end

  # The exporting SDK is only configured when an OTLP endpoint is set, which it is not in test,
  # so the processor is exercised against a provider built here.
  def recorded_span(attributes)
    exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    provider = OpenTelemetry::SDK::Trace::TracerProvider.new
    # The exporting processor is added first, as it is in the configured SDK: the redaction has
    # to land whichever order the two were registered in.
    provider.add_span_processor OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter)
    provider.add_span_processor PairingTokenRedaction::SpanProcessor.new
    provider.tracer("test").in_span("HTTP GET", attributes: attributes) {}
    exporter.finished_spans.sole
  end
end
