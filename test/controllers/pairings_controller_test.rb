require "test_helper"

class PairingsControllerTest < ActionDispatch::IntegrationTest
  FORGED_TOKEN = "kQ5r1zFQTSjmrGWJ8Vc3oLbXpNdYhA2eu7T0iCsRfMw"

  setup do
    @child = children(:pau)
    @link = @child.pairing_links.create!
    @token = @link.generate_token_for(:invitation)
  end

  test "opening a fresh pairing link pairs the iPad and renders the install view (AE15)" do
    assert_difference -> { Device.count }, 1 do
      get pairing_path(token: @token)
    end

    assert_response :success
    assert_equal @child, Device.find_by_token(cookies[Authentication::COOKIE]).child
    assert_select "[data-screen=install]"
  end

  test "the same token presented by another iPad pairs nothing and renders the lost-identity screen" do
    get pairing_path(token: @token)

    other_ipad = open_session

    assert_no_difference -> { Device.count } do
      other_ipad.get pairing_path(token: @token)
    end

    assert_equal 404, other_ipad.response.status
    assert_select other_ipad.html_document.root, "[data-screen=lost-identity]"
    assert_empty other_ipad.cookies[Authentication::COOKIE].to_s
  end

  test "a link past its window pairs nothing, even though no iPad has used it" do
    travel 16.minutes

    assert_no_difference -> { Device.count } do
      get pairing_path(token: @token)
    end

    assert_response :not_found
    assert_select "[data-screen=lost-identity]"
    assert_empty cookies[Authentication::COOKIE].to_s
  end

  test "a forged or truncated token renders the lost-identity screen rather than raising" do
    assert_no_difference -> { Device.count } do
      get pairing_path(token: FORGED_TOKEN)

      assert_response :not_found
      assert_select "[data-screen=lost-identity]"

      get pairing_path(token: @token[0..-5])

      assert_response :not_found
      assert_select "[data-screen=lost-identity]"

      get "/p"

      assert_response :not_found
      assert_select "[data-screen=lost-identity]"
    end
  end

  test "the paired iPad still fetches the manifest and both icons the install view asks for" do
    get pairing_path(token: @token)

    assert_response :success

    get pairing_manifest_path

    assert_response :success

    JSON.parse(response.body)["icons"].each do |icon|
      get icon["src"]

      assert_response :success
      assert_equal "image/png", response.media_type
    end
  end

  test "the iPad keeps studying after the link that paired it is spent and another is issued" do
    travel_to Time.utc(2026, 9, 13, 23, 30)
    get pairing_path(token: @token)
    get "/"

    assert_select "[data-screen=study]"

    @child.pairing_links.create!

    get "/"

    assert_response :success
    assert_select "[data-screen=study]"
    assert_equal @child, Device.find_by_token(cookies[Authentication::COOKIE]).child
  end

  test "the manifest's start URL is the root, carrying no token, and stays inside the root scope" do
    get pairing_path(token: @token)
    get pairing_manifest_path

    assert_response :success
    manifest = JSON.parse response.body
    assert_equal "/", manifest["start_url"]
    assert_not_includes response.body, @token
    assert_equal "/", manifest["scope"]
    assert_equal "standalone", manifest["display"]
    assert_equal @child.name, manifest["name"]
    assert_equal @child.color_hex, manifest["theme_color"]
    assert_equal @child.color_hex, manifest["background_color"]

    small, large = manifest["icons"]
    assert_equal ["180x180", "image/png"], [small["sizes"], small["type"]]
    assert_equal ["512x512", "any maskable"], [large["sizes"], large["purpose"]]
    assert_includes small["src"], "#{@child.color}-180"
    assert_includes large["src"], "#{@child.color}-512"
  end

  test "the install view links the manifest with credentials, so the cookie reaches it" do
    get pairing_path(token: @token)

    assert_select "link[rel=manifest][href=?][crossorigin=use-credentials]", "/p/manifest.webmanifest"
    assert_select "link[rel=apple-touch-icon][href*=?]", "#{@child.color}-180"
  end

  test "an unpaired iPad gets no manifest" do
    get pairing_manifest_path

    assert_response :not_found
    assert_empty response.body
  end

  test "an iPad whose device the agent forgot pairs again from a freshly issued link, not from the spent one (AE17)" do
    travel_to Time.utc(2026, 9, 13, 23, 30)
    get pairing_path(token: @token)
    forgotten_cookie = cookies[Authentication::COOKIE]

    capture_io { Ops::Devices::Forget.call child: @child.name, confirm: true }

    assert_no_difference -> { Device.count } do
      get pairing_path(token: @token)
    end

    assert_response :not_found

    issued = @child.pairing_links.create!

    assert_difference -> { Device.count }, 1 do
      get pairing_path(token: issued.generate_token_for(:invitation))
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
    get pairing_path(token: @token)

    capture_io { Ops::Devices::Forget.call child: @child.name, confirm: true }

    get "/"

    assert_response :success
    assert_select "[data-screen=lost-identity]"
    assert_select "[data-screen=study]", false
  end

  test "a device paired to another link is not reused, so a re-paired iPad gets its own device" do
    other = children(:teo).pairing_links.create!

    get pairing_path(token: other.generate_token_for(:invitation))

    assert_difference -> { Device.count }, 1 do
      get pairing_path(token: @token)
    end

    assert_equal @child, Device.find_by_token(cookies[Authentication::COOKIE]).child
  end

  test "the install view and the manifest both respond with no-store, and the manifest with the manifest content type" do
    get pairing_path(token: @token)

    assert_equal "no-store", response.headers["Cache-Control"]

    get pairing_manifest_path

    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "application/manifest+json", response.media_type
  end

  test "the install screen carries both of the child's colors too" do
    get pairing_path(token: @token)

    style = response.parsed_body.at_css("#screen")["style"]
    assert_includes style, "--child-light: #{@child.color_hex}"
    assert_includes style, "--child-dark: #{@child.color_hex_dark}"
  end

  test "opening an unknown token renders the same screen without leaking whether the token ever existed" do
    get pairing_path(token: FORGED_TOKEN)

    unknown_status, unknown_body = response.status, response.body

    open_session.get pairing_path(token: @token)
    get pairing_path(token: @token)

    assert_equal unknown_status, response.status
    assert_equal without_nonce(unknown_body), without_nonce(response.body)
  end

  test "the lost-identity screen, which is the shared layout without the install view, links no manifest and no per-child icon" do
    get pairing_path(token: FORGED_TOKEN)

    assert_select "link[rel=manifest]", false
    assert_select "link[rel=apple-touch-icon]", false
    assert_select "img", false
  end

  test "the install view carries the legacy Apple standalone meta tags and offers no link to the root" do
    get pairing_path(token: @token)

    assert_select "meta[name='apple-mobile-web-app-capable'][content='yes']"
    assert_select "meta[name='apple-mobile-web-app-status-bar-style']"
    assert_select "meta[name='apple-mobile-web-app-title'][content=?]", @child.name
    assert_select "a", false
  end

  test "the install view replaces itself with the root when it is opened in standalone display mode" do
    get pairing_path(token: @token)

    assert_match "display-mode: standalone", response.body
    assert_match "location.replace", response.body
  end

  test "an unknown suffix on a dot-extension route does not route" do
    get "/p/manifest.webmanifest.json?token=#{CGI.escape @token}"

    assert_response :not_found
  end

  test "the viewport clamps scaling and reaches into the safe area" do
    get pairing_path(token: @token)

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
