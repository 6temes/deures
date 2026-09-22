require "test_helper"

# A pairing URL signs an iPad in as a child for as long as the link is live, and the logs are
# kept for weeks and leave the house. Nothing here is this app's own code: `:token` in
# filter_parameters is what scrubs the query string out of the path Rails logs, and these are
# the proof that the native path covers the pairing routes.
class PairingTokenLoggingTest < ActionDispatch::IntegrationTest
  setup do
    @token = children(:pau).pairing_links.create!.plain_token
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

  private

  # The request-started event is the one whose path still carries the query string — the
  # completed-action event logs the path alone, with no query at all.
  def logged_path
    SemanticLogger.flush
    event = @events.events.find { it.message == "Started" }
    assert event, "no log event carried a request path"
    event.payload[:path]
  end
end
