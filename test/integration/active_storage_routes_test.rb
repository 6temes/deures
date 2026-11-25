require "test_helper"

class ActiveStorageRoutesTest < ActionDispatch::IntegrationTest
  test "no model has an attachment, so a direct upload is not routed" do
    post "/rails/active_storage/direct_uploads",
      params: {blob: {filename: "a.txt", byte_size: 1, checksum: "DMF1ucDxtqgxw5niaXcmYQ==", content_type: "text/plain"}},
      as: :json

    assert_response :not_found
  end

  test "nor is any other Active Storage endpoint" do
    paths = Rails.application.routes.routes.map { it.path.spec.to_s }

    assert_empty paths.grep(%r{\A/rails/active_storage/})
  end
end
