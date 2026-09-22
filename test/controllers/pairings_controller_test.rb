require "test_helper"

class PairingsControllerTest < ActionDispatch::IntegrationTest
  UNKNOWN_TOKEN = "kQ5r1zFQTSjmrGWJ8Vc3oLbXpNdYhA2eu7T0iCsRfMw"

  setup do
    @child = children(:pau)
    @link = @child.pairing_links.create!
    @token = @link.plain_token
  end

  test "opening a valid pairing link sets the pairing cookie and renders the install view linking the per-token manifest and the per-child icon (AE15)" do
    get "/p?token=#{@token}"

    assert_response :success
    assert_equal @child, Device.find_by_token(cookies[Authentication::COOKIE]).child
    assert_select "link[rel=manifest][href=?]", "/p/manifest.webmanifest?token=#{@token}"
    assert_select "link[rel=apple-touch-icon][href=?]", "/p/icon-180.png?token=#{@token}"
  end

  test "the link is claimed by the device that pairs through it, and that device reopening it is not paired a second time" do
    get "/p?token=#{@token}"

    assert_predicate @link.reload, :claimed?
    assert_equal 1, @link.devices.count

    assert_no_difference -> { Device.count } do
      get "/p?token=#{@token}"
    end

    assert_response :success
    assert_equal @child, Device.find_by_token(cookies[Authentication::COOKIE]).child
  end

  test "the same token presented by another iPad pairs nothing and renders the lost-identity screen" do
    get "/p?token=#{@token}"

    other_ipad = open_session

    assert_no_difference -> { Device.count } do
      other_ipad.get "/p?token=#{@token}"
    end

    assert_equal 404, other_ipad.response.status
    assert_select other_ipad.html_document.root, "[data-screen=lost-identity]"
    assert_empty other_ipad.cookies[Authentication::COOKIE].to_s
  end

  test "a link past its window pairs nothing, even though no device has claimed it" do
    travel PairingLink::WINDOW + 1.second

    assert_no_difference -> { Device.count } do
      get "/p?token=#{@token}"
    end

    assert_response :not_found
    assert_select "[data-screen=lost-identity]"
    assert_empty cookies[Authentication::COOKIE].to_s
  end

  test "the iPad that claimed the link still fetches the manifest and both icons the install view asks for" do
    get "/p?token=#{@token}"

    assert_predicate @link.reload, :claimed?

    get "/p/manifest.webmanifest?token=#{@token}"

    assert_response :success

    get "/p/icon-180.png?token=#{@token}"

    assert_response :success

    get "/p/icon-512.png?token=#{@token}"

    assert_response :success
  end

  test "revoking the link still signs out the iPad that paired through it" do
    travel_to Time.utc(2026, 9, 13, 23, 30)
    get "/p?token=#{@token}"
    get "/"

    assert_select "[data-screen=study]"

    @link.revoke!

    get "/"

    assert_response :success
    assert_select "[data-screen=lost-identity]"
    assert_select "[data-screen=study]", false
  end

  test "an iPad whose device the agent forgot pairs again from a freshly issued link, not from the spent one (AE17)" do
    travel_to Time.utc(2026, 9, 13, 23, 30)
    get "/p?token=#{@token}"
    forgotten_cookie = cookies[Authentication::COOKIE]

    capture_io { Ops::Devices::Forget.call child: @child.name, confirm: true }

    assert_no_difference -> { Device.count } do
      get "/p?token=#{@token}"
    end

    assert_response :not_found

    issued = @child.pairing_links.create!

    assert_difference -> { Device.count }, 1 do
      get "/p?token=#{issued.plain_token}"
    end

    assert_not_equal forgotten_cookie, cookies[Authentication::COOKIE]
    assert_equal @child, Device.find_by_token(cookies[Authentication::COOKIE]).child

    get "/"

    assert_response :success
    assert_select "[data-screen=study]"
    assert_select ".question", "23 + 19"
  end

  test "a forgotten device's cookie alone gets the grown-up screen (AE17)" do
    travel_to Time.utc(2026, 9, 13, 23, 30)
    get "/p?token=#{@token}"

    capture_io { Ops::Devices::Forget.call child: @child.name, confirm: true }

    get "/"

    assert_response :success
    assert_select "[data-screen=lost-identity]"
    assert_select "[data-screen=study]", false
  end

  test "a device paired to another link is not reused, so a re-paired iPad gets its own device" do
    other = children(:teo).pairing_links.create!

    get "/p?token=#{other.plain_token}"

    assert_difference -> { Device.count }, 1 do
      get "/p?token=#{@token}"
    end

    assert_equal @child, Device.find_by_token(cookies[Authentication::COOKIE]).child
  end

  test "the manifest's start URL is the root, carrying no token, and stays inside the root scope" do
    get "/p/manifest.webmanifest?token=#{@token}"

    assert_response :success
    manifest = JSON.parse response.body
    assert_equal "/", manifest["start_url"]
    assert_not_includes manifest["start_url"], @token
    assert_equal "/", manifest["scope"]
    assert_equal "standalone", manifest["display"]
    assert_equal @child.name, manifest["name"]
    assert_equal @child.color_hex, manifest["theme_color"]
    assert_equal @child.color_hex, manifest["background_color"]

    small, large = manifest["icons"]
    assert_equal ["/p/icon-180.png?token=#{@token}", "180x180"], [small["src"], small["sizes"]]
    assert_equal ["/p/icon-512.png?token=#{@token}", "512x512"], [large["src"], large["sizes"]]
    assert_equal "any maskable", large["purpose"]
  end

  test "the install view and the manifest both respond with no-store, and the manifest with the manifest content type" do
    get "/p?token=#{@token}"

    assert_equal "no-store", response.headers["Cache-Control"]

    get "/p/manifest.webmanifest?token=#{@token}"

    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "application/manifest+json", response.media_type
  end

  test "the icon route returns the PNG for the paired child's color with no-store" do
    get "/p/icon-180.png?token=#{@token}"

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal Rails.root.join("app/assets/images/icons/#{@child.color}-180.png").binread, response.body
  end

  test "the install screen carries both of the child's colors too" do
    get "/p?token=#{@token}"

    style = response.parsed_body.at_css("#screen")["style"]
    assert_includes style, "--child-light: #{@child.color_hex}"
    assert_includes style, "--child-dark: #{@child.color_hex_dark}"
  end

  test "the 512 icon route returns the larger PNG for the paired child's color" do
    get "/p/icon-512.png?token=#{@token}"

    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal Rails.root.join("app/assets/images/icons/#{@child.color}-512.png").binread, response.body
  end

  test "a revoked or unknown token gets no icon, at either size, and no manifest" do
    @link.revoke!

    get "/p/icon-180.png?token=#{@token}"

    assert_response :not_found
    assert_empty response.body

    # A pairing link signs an iPad in as a child, so revoking it has to close every route that
    # answers for one — a size added without this assertion would stay open silently.
    get "/p/icon-512.png?token=#{@token}"

    assert_response :not_found
    assert_empty response.body

    get "/p/manifest.webmanifest?token=#{@token}"

    assert_response :not_found

    get "/p/icon-180.png?token=#{UNKNOWN_TOKEN}"

    assert_response :not_found

    get "/p/icon-512.png?token=#{UNKNOWN_TOKEN}"

    assert_response :not_found
  end

  test "opening a revoked link renders the lost-identity screen and sets no cookie" do
    @link.revoke!

    get "/p?token=#{@token}"

    assert_response :not_found
    assert_select "[data-screen=lost-identity]"
    assert_empty cookies[Authentication::COOKIE].to_s
    assert_equal 0, @link.devices.count
  end

  test "an expired link gets no icon, at either size, and no manifest" do
    travel PairingLink::WINDOW + 1.second

    get "/p/icon-180.png?token=#{@token}"

    assert_response :not_found

    get "/p/icon-512.png?token=#{@token}"

    assert_response :not_found

    get "/p/manifest.webmanifest?token=#{@token}"

    assert_response :not_found
  end

  test "opening an unknown token renders the same screen without leaking whether the token ever existed" do
    get "/p?token=#{UNKNOWN_TOKEN}"

    unknown_status, unknown_body = response.status, response.body

    @link.revoke!
    get "/p?token=#{@token}"

    assert_equal unknown_status, response.status
    assert_equal without_nonce(unknown_body), without_nonce(response.body)
  end

  test "the lost-identity screen, which is the shared layout without the install view, links no manifest and no per-child icon" do
    @link.revoke!

    get "/p?token=#{@token}"

    assert_select "link[rel=manifest]", false
    assert_select "link[rel=apple-touch-icon]", false
    assert_select "img", false
  end

  test "the install view carries the legacy Apple standalone meta tags and offers no link to the root" do
    get "/p?token=#{@token}"

    assert_select "meta[name='apple-mobile-web-app-capable'][content='yes']"
    assert_select "meta[name='apple-mobile-web-app-status-bar-style']"
    assert_select "meta[name='apple-mobile-web-app-title'][content=?]", @child.name
    assert_select "a", false
  end

  test "the install view replaces itself with the root when it is opened in standalone display mode" do
    get "/p?token=#{@token}"

    assert_match "display-mode: standalone", response.body
    assert_match "location.replace", response.body
  end

  test "an unknown suffix on a dot-extension route does not route" do
    get "/p/manifest.webmanifest.json?token=#{@token}"

    assert_response :not_found

    get "/p/icon-180.png/somewhere?token=#{@token}"

    assert_response :not_found
  end

  test "the viewport clamps scaling and reaches into the safe area" do
    get "/p?token=#{@token}"

    assert_select "meta[name=viewport][content=?]",
      "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover"
  end

  private

  # The CSP nonce is fresh per request by design, so it is the one part of these two bodies
  # that must differ. Everything else still has to match byte for byte.
  def without_nonce(body)
    body.gsub(/nonce="[^"]*"/, 'nonce=""')
      .gsub(/(<meta name="csp-nonce" content=)"[^"]*"/, '\\1""')
  end
end
