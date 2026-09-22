require "test_helper"

# The app is wordless and its users are children, so a browser that cannot run it must fail on a
# screen an adult reads rather than render something broken and silent.
class BrowserSupportTest < ActionDispatch::IntegrationTest
  SAFARI_16 = "Mozilla/5.0 (iPad; CPU OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Safari/605.1.15"
  SAFARI_18 = "Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

  test "refuses an iPad too old to run the app" do
    get root_path, headers: {"HTTP_USER_AGENT" => SAFARI_16}

    assert_response :not_acceptable
  end

  test "serves an iPad that can run it" do
    get root_path, headers: {"HTTP_USER_AGENT" => SAFARI_18}

    assert_response :success
  end
end
