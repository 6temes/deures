require "test_helper"
require "opentelemetry/sdk"

# A pairing URL is the whole credential: it signs an iPad in as a child, it does not expire,
# and only a revoke retires it. Logs and traces both leave the house and are kept for weeks,
# so the token must not reach either. Rails filters the logged query string itself; the span
# attributes are what needs a processor of this app's own.
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
    get "/p?token=#{@token}"

    assert_equal "/p?token=[FILTERED]", logged_path
  end

  test "the logged path of a pairing icon carries no token" do
    get "/p/icon-180.png?token=#{@token}"

    assert_equal "/p/icon-180.png?token=[FILTERED]", logged_path
  end

  test "no log line anywhere carries the token" do
    get "/p?token=#{@token}"
    get "/p/manifest.webmanifest?token=#{@token}"
    SemanticLogger.flush

    assert_not_includes @events.to_h.to_s, @token
  end

  test "no log line carries the token when nothing under the pairing path is routed" do
    get "/p/nothing-is-routed-here?token=#{@token}"
    SemanticLogger.flush

    assert_not_includes @events.to_h.to_s, @token
  end

  test "the recorded span carries the scrubbed query under either semantic convention" do
    span = recorded_span "http.target" => "/p/icon-512.png?token=#{@token}"
    assert_equal "/p/icon-512.png?token=[FILTERED]", span.attributes["http.target"]

    span = recorded_span "url.query" => "token=#{@token}"
    assert_equal "token=[FILTERED]", span.attributes["url.query"]
  end

  test "the recorded span keeps a query that carries no token untouched" do
    span = recorded_span "http.target" => "/p?launch=1"

    assert_equal "/p?launch=1", span.attributes["http.target"]
  end

  test "the recorded span leaves the path alone" do
    span = recorded_span "url.path" => "/p", "url.query" => "token=#{@token}"

    assert_equal "/p", span.attributes["url.path"]
  end

  private

  # The request-started event is the one whose path still carries the query string — the
  # completed-action event logs the path alone, with no query at all.
  def logged_path
    SemanticLogger.flush
    event = @events.events.find { it.message == "Started" }
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
