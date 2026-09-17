require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "the install screen's inline script carries a nonce the header accepts" do
    get "/p/#{children(:pau).pairing_links.create!.plain_token}"

    assert_response :success
    nonce = response.body[/<script nonce="([^"]*)"/, 1]

    # The install screen is reached with no session yet, so a nonce generated from the session
    # id would be the empty string here — an empty nonce matches nothing, and the one screen a
    # parent ever sees would be the one that breaks.
    assert_not_equal "", nonce
    assert_includes response.headers["Content-Security-Policy"], "'nonce-#{nonce}'"
  end

  test "a fresh nonce is issued per request" do
    nonces = 2.times.map do
      get "/p/#{children(:pau).pairing_links.create!.plain_token}"
      response.body[/<script nonce="([^"]*)"/, 1]
    end

    assert_equal 2, nonces.uniq.size
  end

  test "style attributes are permitted, and nothing else inline is" do
    get "/p/#{children(:pau).pairing_links.create!.plain_token}"

    policy = response.headers["Content-Security-Policy"]

    assert_includes policy, "style-src-attr 'unsafe-inline'"
    assert_not_includes policy, "script-src 'self' 'unsafe-inline'"
    assert_includes policy, "object-src 'none'"
    assert_includes policy, "frame-ancestors 'none'"
  end
end
