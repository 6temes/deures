require "test_helper"

# A pairing URL signs an iPad in as a child for as long as the link is live, and the logs are
# kept for weeks and leave the house. Nothing here is this app's own code: `:token` in
# filter_parameters is what scrubs the query string out of the path Rails logs, and these are
# the proof that the native path covers the pairing routes.
class PairingTokenLoggingTest < ActionDispatch::IntegrationTest
  setup do
    @token = children(:pau).pairing_links.create!.generate_token_for(:invitation)
    @events = SemanticLogger::Test::CaptureLogEvents.new
    SemanticLogger.add_appender appender: @events
  end

  teardown do
    SemanticLogger.remove_appender @events
  end

  test "the logged path of a pairing request carries no token" do
    get "/p?token=#{CGI.escape @token}"

    assert_equal "/p?token=[FILTERED]", logged_path("/p?")
  end

  test "the logged path of an unrouted path under the pairing path carries no token" do
    get "/p/nothing-is-routed-here?token=#{CGI.escape @token}"

    assert_equal "/p/nothing-is-routed-here?token=[FILTERED]", logged_path("/p/nothing-is-routed-here")
  end

  test "no log line anywhere carries the token" do
    get "/p?token=#{CGI.escape @token}"
    get "/p/manifest.webmanifest?token=#{CGI.escape @token}"
    SemanticLogger.flush

    assert_not_includes @events.to_h.to_s, @token
  end

  test "no log line carries the token when nothing under the pairing path is routed" do
    get "/p/nothing-is-routed-here?token=#{CGI.escape @token}"
    SemanticLogger.flush

    assert_not_includes @events.to_h.to_s, @token
  end

  private

  # The request-started event is the one whose path still carries the query string — the
  # completed-action event logs the path alone, with no query at all. Semantic Logger delivers
  # to its appenders on a thread of its own, so an event logged by an earlier test can arrive
  # after this appender is attached; the route is what picks this request's event out of them.
  def logged_path(route)
    SemanticLogger.flush
    event = @events.events.find { it.message == "Started" && it.payload[:path].to_s.start_with?(route) }
    assert event, "no log event carried a request path starting #{route}"
    event.payload[:path]
  end
end
