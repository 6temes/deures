require "test_helper"

class PairingRateLimitTest < ActionDispatch::IntegrationTest
  setup { ActionController::Base.cache_store.clear }

  test "stops answering a caller that keeps asking" do
    10.times { get pairing_path(token: "not-a-token") }
    assert_response :not_found

    get pairing_path(token: "not-a-token")
    assert_response :too_many_requests
  end
end
