require "test_helper"

# Two properties of the replication config that nothing downstream would report: Litestream 0.5
# drops the replica-level retention keys silently rather than refusing them, so a config that
# still carries them keeps a retention nobody set; and this repository is published, so the
# backup host and the path it writes to may only reach the config through the environment.
class LitestreamTest < ActiveSupport::TestCase
  CONFIG = Rails.root.join("config/litestream.yml").read
  SNAPSHOT = /^snapshot:\n(?:[ \t]+.*\n)*/

  test "keeps retention in the top-level snapshot block, where 0.5 still reads it" do
    assert_match(/^snapshot:\n(?:  .+\n)*  retention: /, CONFIG)

    elsewhere = CONFIG.sub(SNAPSHOT, "")
    %w[retention snapshot-interval retention-check-interval].each do |key|
      assert_no_match(/^\s*#{key}: /, elsewhere)
    end
  end

  test "keeps snapshots longer than the interval that replaces them" do
    interval, retention = CONFIG[SNAPSHOT].scan(/^  (?:interval|retention): (\d+)h$/).flatten.map(&:to_i)

    assert_operator retention, :>, interval
  end

  test "names no host, address or server path of its own" do
    assert_no_match(/\d+\.\d+\.\d+\.\d+/, CONFIG)

    CONFIG.scan(%r{(?<![\w\}])/[\w./-]+}) do |path|
      assert path.start_with?("/rails/storage", "/etc/litestream"),
        "#{path} is a path this published repository should be taking from the environment"
    end
  end
end
