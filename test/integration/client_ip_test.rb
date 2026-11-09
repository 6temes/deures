require "test_helper"

class ClientIpTest < ActionDispatch::IntegrationTest
  VISITOR = "198.51.100.7"
  CHAIN = "#{VISITOR}, 172.18.0.2"

  test "ignores a Forwarded header naming another client" do
    get_up "Forwarded" => "for=203.0.113.9", "X-Forwarded-For" => CHAIN

    assert_visitor
  end

  test "ignores a private Client-IP header" do
    get_up "Client-IP" => "10.0.0.1", "X-Forwarded-For" => CHAIN

    assert_visitor
  end

  test "serves a request whose Client-IP is missing from X-Forwarded-For" do
    get_up "Client-IP" => "203.0.113.5", "X-Forwarded-For" => CHAIN

    assert_visitor
  end

  test "takes the visitor past a loopback address the visitor prepended" do
    get_up "Client-IP" => "203.0.113.5", "X-Forwarded-For" => "127.0.0.1, #{CHAIN}"

    assert_visitor
  end

  test "falls back to Client-IP when there is no X-Forwarded-For" do
    get_up "Client-IP" => "203.0.113.5"

    assert_response :success
    assert_equal "203.0.113.5", request.remote_ip
  end

  private

  def get_up(headers)
    get "/up", headers:, env: {"REMOTE_ADDR" => "127.0.0.1"}
  end

  def assert_visitor
    assert_response :success
    assert_equal VISITOR, request.remote_ip
    assert_equal VISITOR, request.ip
  end
end
