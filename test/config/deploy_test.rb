require "test_helper"

# This repository is published, so the server, the application's domain, the private network and
# the backup host may only reach the deploy configuration through the environment. Nothing
# downstream would report a value written in by hand: Kamal would deploy perfectly well.
class DeployTest < ActiveSupport::TestCase
  FILES = Rails.root.glob("config/deploy.yml").concat(Rails.root.glob(".kamal/**/*")).select(&:file?)

  test "names no address of its own" do
    FILES.each do |file|
      addresses = file.read.scan(/\b\d{1,3}(?:\.\d{1,3}){3}\b/) - ["0.0.0.0"]
      assert_empty addresses, "#{file.basename} names #{addresses.join(", ")}"
    end
  end

  test "names no household domain, server directory or login" do
    FILES.each do |file|
      %w[6temes /srv/ daniel].each do |literal|
        assert_not_includes file.read, literal, "#{file.basename} names #{literal}"
      end
    end
  end
end
