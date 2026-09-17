require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  class ProbesController < ApplicationController
    def show
      render plain: "child:#{Current.child&.name} paired:#{paired?}"
    end
  end

  class OpenProbesController < ApplicationController
    allow_unauthenticated_access

    def show
      render plain: "child:#{Current.child&.name} paired:#{paired?}"
    end
  end

  class PairingProbesController < ApplicationController
    allow_unauthenticated_access

    def show
      start_pairing_for PairingLink.find_by_token(params[:token])
      render plain: "child:#{Current.child&.name} paired:#{paired?}"
    end
  end

  with_routing do |routes|
    routes.draw do
      get "probe" => "authentication_test/probes#show"
      get "open-probe" => "authentication_test/open_probes#show"
      get "pair/:token" => "authentication_test/pairing_probes#show"
    end
  end

  test "a request carrying a paired device's cookie resolves to that child with no redirect (AE15)" do
    pair_device_as children(:pau)

    get "/probe"

    assert_response :success
    assert_equal "child:Pau paired:true", response.body
  end

  test "after the link is revoked, the same cookie resolves to no child (AE15)" do
    device = pair_device_as children(:pau)

    device.pairing_link.revoke!
    get "/probe"

    assert_response :success
    assert_equal "child: paired:false", response.body
  end

  test "an unknown cookie resolves to no child rather than raising" do
    cookies[Authentication::COOKIE] = "8Uu5OTFBaHBBSlNlRzg5aHVudGZvcmFrZXl0b2tlbg"

    get "/probe"

    assert_response :success
    assert_equal "child: paired:false", response.body
  end

  test "a malformed cookie resolves to no child rather than raising" do
    cookies[Authentication::COOKIE] = "%%-not-base64-%%"

    get "/probe"

    assert_response :success
    assert_equal "child: paired:false", response.body
  end

  test "no cookie at all resolves to no child" do
    get "/probe"

    assert_response :success
    assert_equal "child: paired:false", response.body
  end

  test "the cookie holds the device's own token unsigned, HttpOnly and SameSite Lax" do
    device = pair_device_as children(:pau)

    get "/probe"

    assert_equal device.plain_token, cookies[Authentication::COOKIE]
    assert_match(/;\s*HttpOnly/i, pairing_cookie_header)
    assert_match(/;\s*SameSite=Lax/i, pairing_cookie_header)
    assert_no_match(/;\s*Secure/i, pairing_cookie_header)
  end

  test "the cookie's expiry moves forward on a later request" do
    pair_device_as children(:pau)

    travel_to Time.utc(2026, 9, 14, 3) do
      get "/probe"

      assert_in_delta 2.years.from_now.to_i, pairing_cookie_expiry.to_i, 5
    end

    travel_to Time.utc(2026, 10, 14, 3) do
      get "/probe"

      assert_in_delta 2.years.from_now.to_i, pairing_cookie_expiry.to_i, 5
      assert_operator pairing_cookie_expiry, :>, Time.utc(2028, 9, 14, 3)
    end
  end

  test "a revoked device is not given a fresh expiry" do
    device = pair_device_as children(:pau)
    device.pairing_link.revoke!

    get "/probe"

    assert_nil pairing_cookie_header
  end

  test "an authenticated request stamps the device's last seen time" do
    device = pair_device_as children(:pau)

    travel_to Time.utc(2026, 9, 14, 3) do
      get "/probe"
    end

    assert_equal Time.utc(2026, 9, 14, 3), device.reload.last_seen_at
  end

  test "allow_unauthenticated_access leaves a route open with no child resolved" do
    pair_device_as children(:pau)

    get "/open-probe"

    assert_response :success
    assert_equal "child: paired:false", response.body
  end

  test "pairing writes the cookie the next request resolves from" do
    link = children(:teo).pairing_links.create!

    get "/pair/#{link.plain_token}"

    assert_response :success
    assert_equal "child:Teo paired:true", response.body

    get "/probe"

    assert_equal "child:Teo paired:true", response.body
    assert_equal 1, link.devices.count
  end

  private

  def pairing_cookie_header
    Array(response.headers["set-cookie"]).flat_map { it.split("\n") }
      .find { it.start_with?("#{Authentication::COOKIE}=") }
  end

  def pairing_cookie_expiry
    Time.httpdate pairing_cookie_header[/expires=([^;]+)/i, 1]
  end
end
