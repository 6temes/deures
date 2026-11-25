require "test_helper"

# Rails sends the policy under the Feature-Policy header name, in that header's syntax.
class PermissionsPolicyTest < ActionDispatch::IntegrationTest
  test "denies the device features the app never asks for" do
    get "/"

    policy = response.headers["Feature-Policy"].to_s
    %w[camera microphone geolocation payment usb].each do |feature|
      assert_includes policy, "#{feature} 'none'"
    end
  end

  test "keeps autoplay for the number pad's click" do
    get "/"

    assert_includes response.headers["Feature-Policy"].to_s, "autoplay 'self'"
  end
end
