require "test_helper"

# Informant keeps what it captures in this app's own database, which Litestream replicates off
# the house. A pairing URL signs an iPad in as a child for as long as the link is live, so a
# captured 500 on a pairing path must not be the copy of that credential everything else was
# scrubbed to avoid.
class InformantPairingTokenTest < ActionDispatch::IntegrationTest
  setup do
    @link = children(:pau).pairing_links.create!
    @token = @link.generate_token_for(:invitation)
    # A configuration of its own, so that enabling capture and registering a callback below stay
    # inside this test.
    @config = RailsInformant.config
    RailsInformant.config = RailsInformant::Configuration.new
    RailsInformant.config.capture_errors = true
    RailsInformant.reset_caches!
    # The gem reads .git/HEAD itself when no deploy sha is in the environment, and raises out of
    # the whole capture where .git is a file rather than a directory, as it is in a worktree.
    # The deployed container always has one of these set, so naming it here is what production
    # looks like rather than a way around the gem.
    @git_sha = ENV["GIT_SHA"]
    ENV["GIT_SHA"] = "informant-pairing-token-test"
  end

  teardown do
    ENV["GIT_SHA"] = @git_sha
    RailsInformant.config = @config
    RailsInformant.reset_caches!
  end

  # The capture middleware is only inserted when capture is on at boot, which it is not in test.
  # Wrapping the application in it is the same request through the same middleware.
  def app = RailsInformant::Middleware::ErrorCapture.new(Rails.application)

  test "the captured request url of a pairing request carries no token" do
    capture_failure_on "/p?token=#{CGI.escape @token}"

    assert_equal "http://www.example.com/p?token=%5BFILTERED%5D", occurrence.request_context["url"]
  end

  test "the captured request url keeps the path under a pairing token" do
    capture_failure_on "/p/manifest.webmanifest?token=#{CGI.escape @token}"

    assert_equal "http://www.example.com/p/manifest.webmanifest?token=%5BFILTERED%5D", occurrence.request_context["url"]
  end

  test "nothing informant persists carries the token" do
    capture_failure_on "/p?token=#{CGI.escape @token}"

    assert_not_includes RailsInformant::ErrorGroup.all.map(&:attributes).to_s, @token
    assert_not_includes RailsInformant::Occurrence.all.map(&:attributes).to_s, @token
  end

  test "the path informant hands its callbacks carries no token" do
    paths = []
    RailsInformant.config.before_record { paths << it.request_path }

    capture_failure_on "/p?token=#{CGI.escape @token}"

    assert_equal ["/p"], paths
  end

  private

  # Resolving the device cookie is the one thing every pairing path does, whatever it answers
  # with, so failing there reaches each of them from the same stub.
  def capture_failure_on(path)
    Device.stub :find_by_token, ->(_) { raise "the card deck caught fire" } do
      assert_raises(RuntimeError) { get path }
    end
  end

  def occurrence = RailsInformant::Occurrence.sole
end
