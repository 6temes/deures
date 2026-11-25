require "test_helper"

class PairingRateLimitTest < ActionDispatch::IntegrationTest
  test "stops answering a caller that keeps asking" do
    10.times { get pairing_path(token: "not-a-token") }
    assert_response :not_found

    get pairing_path(token: "not-a-token")
    assert_response :too_many_requests
  end

  test "stops answering a caller that keeps tapping" do
    10.times { post pairing_path, params: {token: "not-a-token"} }
    assert_response :not_found

    post pairing_path, params: {token: "not-a-token"}
    assert_response :too_many_requests
  end
end
