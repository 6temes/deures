require "test_helper"

class PrometheusPathFilterTest < ActiveSupport::TestCase
  test "skips the health check and the assets" do
    assert PrometheusPathFilter.skip?("/up")
    assert PrometheusPathFilter.skip?("/assets/application-abc123.css")
  end

  test "counts an ordinary request" do
    assert_not PrometheusPathFilter.skip?("/")
    assert_not PrometheusPathFilter.skip?("/p/sometoken")
  end
end
