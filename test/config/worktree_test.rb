require "test_helper"
require "minitest/mock"
require "puma/configuration"
require_relative "../../config/worktree"

class WorktreeTest < ActiveSupport::TestCase
  test "a linked worktree is named after the SHA-256 of its path" do
    in_checkout(linked: true) do |root|
      File.stub(:realpath, "/srv/worktrees/app/feature-x") do
        assert_equal "4399c230", Worktree.identity(root)
        assert_equal 3692, Worktree.port(root, 3000)
        assert_equal "app_test_wt_4399c230", Worktree.database_name("app_test", root)
      end
    end
  end

  test "the main checkout keeps the default port and database name" do
    in_checkout(linked: false) do |root|
      assert_nil Worktree.identity(root)
      assert_equal 3000, Worktree.port(root, 3000)
      assert_equal "app_test", Worktree.database_name("app_test", root)
    end
  end

  test "a linked worktree port stays within 3100 to 3899" do
    Dir.mktmpdir do |dir|
      ports = Array.new(200) do |i|
        root = File.join(dir, "feature-#{i}")
        Dir.mkdir(root)
        File.write(File.join(root, ".git"), "")
        Worktree.port(root, 3000)
      end

      assert_empty(ports.reject { it.in?(3100..3899) })
    end
  end

  test "puma binds the derived port in a linked worktree" do
    in_checkout(linked: true) do |root|
      with_port(nil) do
        assert_equal Worktree.port(root, 3000), puma_port(root)
      end
    end
  end

  test "puma binds an explicit PORT over the derived port" do
    in_checkout(linked: true) do |root|
      with_port("4567") do
        assert_equal 4567, puma_port(root)
      end
    end
  end

  test "puma binds 3000 in the main checkout" do
    in_checkout(linked: false) do |root|
      with_port(nil) do
        assert_equal 3000, puma_port(root)
      end
    end
  end

  private

  def in_checkout(linked:)
    Dir.mktmpdir do |root|
      git = File.join(root, ".git")
      linked ? File.write(git, "gitdir: /elsewhere\n") : Dir.mkdir(git)
      yield root
    end
  end

  # Copies puma.rb into the fixture because it finds the checkout from its own __dir__.
  def puma_port(root)
    config_dir = File.join(root, "config")
    Dir.mkdir(config_dir)
    FileUtils.cp(Rails.root.join("config/puma.rb"), config_dir)
    FileUtils.ln_s(Rails.root.join("config/worktree.rb"), config_dir)

    puma = Puma::Configuration.new(config_files: ["#{config_dir}/puma.rb"])
    URI(puma.clamp[:binds].sole).port
  end

  def with_port(value)
    original = ENV.fetch("PORT", nil)
    ENV["PORT"] = value
    yield
  ensure
    ENV["PORT"] = original
  end
end
