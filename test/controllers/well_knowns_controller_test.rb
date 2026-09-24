require "test_helper"

class WellKnownsControllerTest < ActionDispatch::IntegrationTest
  APP_ID = "TEAMID0000.org.example.deures"
  PATH = "/.well-known/apple-app-site-association"

  setup { @app_id_was = ENV["APPLE_APP_ID"] }
  teardown { ENV["APPLE_APP_ID"] = @app_id_was }

  test "the association file lists the app for the pairing path and its token, as JSON" do
    ENV["APPLE_APP_ID"] = APP_ID

    get PATH

    assert_response :success
    assert_equal "application/json", response.media_type
    details = JSON.parse(response.body).dig("applinks", "details")
    assert_equal [[APP_ID]], details.pluck("appIDs")
    assert_equal [{"/" => "/p", "?" => {"token" => "?*"}}], details.sole["components"]
  end

  test "without an app ID the file does not exist" do
    ENV.delete "APPLE_APP_ID"

    get PATH

    assert_response :not_found
    assert_empty response.body
  end

  test "Apple's fetch, with no device cookie and no browser version, gets the file itself rather than a redirect" do
    ENV["APPLE_APP_ID"] = APP_ID

    get PATH, headers: {"User-Agent" => "AASA-Bot/1.0.0"}

    assert_response :success
    assert_empty cookies[Authentication::COOKIE].to_s
  end

  test "the file is served at its bare name only" do
    ENV["APPLE_APP_ID"] = APP_ID

    get "#{PATH}.json"

    assert_response :not_found
  end
end
