require "test_helper"

class PermissionsPolicyTest < ActionDispatch::IntegrationTest
  test "a response denies the device features the app never asks for, under both header names" do
    get "/"

    assert_includes response.headers["Permissions-Policy"].to_s.split(", "), "camera=()"
    assert_includes response.headers["Permissions-Policy"].to_s, "picture-in-picture=()"
    assert_includes response.headers["Feature-Policy"].to_s, "camera 'none'"
  end

  test "keeps autoplay for the number pad's click" do
    get "/"

    assert_not_includes response.headers["Permissions-Policy"].to_s, "autoplay"
    assert_includes response.headers["Feature-Policy"].to_s, "autoplay 'self'"
  end
end
