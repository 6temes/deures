require "test_helper"

# Active Storage's engine is loaded for the deploy shape this app shares with its neighbours, not
# for uploads: nothing here serves or receives a blob over HTTP. The app is open to the internet
# with no gate in front of it, so its routes would be an upload and redirect surface with no
# caller behind it.
class RoutesTest < ActiveSupport::TestCase
  test "draws no Active Storage route" do
    controllers = Rails.application.routes.routes.filter_map { it.defaults[:controller] }

    assert_empty controllers.grep(/\Aactive_storage/)
  end
end
