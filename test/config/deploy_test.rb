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

  # The container side of a mount is this image's own and belongs here; a shebang and a shell
  # redirect belong to every Unix. Anything else absolute is a path on the server, which is
  # configuration — and the host side of the two Litestream mounts was exactly that until the
  # list below refused it.
  IMAGE_PATHS = %w[/dev/null /etc/litestream /home/rails /rails /root/.ssh /up /usr/bin/env]

  test "names no path of the server's own" do
    FILES.each do |file|
      file.read.scan(%r{(?<![\w\}/*])/\w[\w./-]*}) do |path|
        assert path.start_with?(*IMAGE_PATHS), "#{file.basename} names #{path}, which is the server's"
      end
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
