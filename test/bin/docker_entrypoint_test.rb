require "test_helper"
require "open3"
require "tmpdir"

# The boot gate is the one place that stands between a fresh volume and a replicator copying an
# empty database over the children's history, so it is drilled rather than read. The script is
# run as the container runs it, with a `litestream` on PATH that records what it was asked to do
# and a storage directory the test owns — the one substitution, asserted below, is the absolute
# storage path, which no test can create on a developer's machine.
class DockerEntrypointTest < ActiveSupport::TestCase
  ENTRYPOINT = Rails.root.join("bin/docker-entrypoint").read
  STORAGE = "/rails/storage"
  REFUSAL = "refusing to boot"

  test "passes a command that is not the server through without restoring or refusing" do
    run = boot "./bin/rails", "db:prepare"

    assert_equal "", run[:litestream]
    assert_not_includes run[:stderr], REFUSAL
    assert_includes run[:stdout], "rails db:prepare"
    assert_predicate run[:status], :success?
  end

  test "restores the primary before the guard, and refuses to boot when the restore found nothing" do
    run = boot "./bin/thrust", "./bin/rails", "server"

    assert_equal ["restore", "-config", "/etc/litestream.yml", "-if-db-not-exists",
      "-if-replica-exists", run[:primary]], run[:litestream].split
    assert_includes run[:stderr], REFUSAL
    assert_equal 1, run[:status].exitstatus
  end

  test "boots when the restore put the primary there" do
    run = boot "./bin/thrust", "./bin/rails", "server", restores: true

    assert_not_includes run[:stderr], REFUSAL
    assert_includes run[:stdout], "rails db:prepare"
    assert_includes run[:stdout], "thrust ./bin/rails server"
    assert_predicate run[:status], :success?
  end

  test "fails the boot on a restore error rather than reading it as an absent replica" do
    run = boot "./bin/thrust", "./bin/rails", "server", exit_status: 3

    assert_includes run[:stderr], "cannot connect to the replica"
    assert_not_includes run[:stderr], REFUSAL
    assert_not_includes run[:stdout], "rails db:prepare"
    assert_not_predicate run[:status], :success?
  end

  test "boots past a restore that is a no-op because the primary is already on the volume" do
    run = boot "./bin/thrust", "./bin/rails", "server", database: true

    assert_includes run[:litestream], "-if-db-not-exists"
    assert_not_includes run[:stderr], REFUSAL
    assert_includes run[:stdout], "thrust ./bin/rails server"
    assert_predicate run[:status], :success?
  end

  private

  # Runs the entrypoint with the given arguments in a throwaway container root. `restores` makes
  # the stubbed litestream write the primary, as a real restore from a replica would; `database`
  # puts one there before it runs, as a redeployed volume would.
  def boot(*arguments, restores: false, database: false, exit_status: 0)
    Dir.mktmpdir do |root|
      storage = File.join(root, "storage")
      FileUtils.mkdir_p storage
      primary = File.join(storage, "production.sqlite3")
      File.write primary, "" if database
      log = File.join(root, "litestream.log")

      write root, "bin/docker-entrypoint", sandboxed(storage)
      write root, "bin/rails", %(#!/bin/bash\necho "rails ${@}"\n)
      write root, "bin/thrust", %(#!/bin/bash\necho "thrust ${@}"\n)
      write root, "stub/litestream", <<~STUB
        #!/bin/bash
        echo "${@}" >> #{log}
        #{"touch #{primary}" if restores}
        if [ #{exit_status} -ne 0 ]; then
          echo "cannot connect to the replica" >&2
        fi
        exit #{exit_status}
      STUB

      # [command, argv0], because the temporary directory's path can carry a space and Ruby
      # splits a bare command string on whitespace before exec'ing it.
      entrypoint = File.join(root, "bin/docker-entrypoint")
      stdout, stderr, status = Open3.capture3(
        {"PATH" => "#{root}/stub:#{ENV["PATH"]}"},
        [entrypoint, entrypoint], *arguments, chdir: root
      )

      {stdout:, stderr:, status:, primary:,
       litestream: File.exist?(log) ? File.read(log).strip : ""}
    end
  end

  # The script names the container's storage directory absolutely, which is the whole point of
  # the guard and is not creatable here. The assertion is what keeps this from silently testing
  # a script the substitution missed.
  def sandboxed(storage)
    assert_includes ENTRYPOINT, STORAGE
    ENTRYPOINT.gsub(STORAGE, storage)
  end

  def write(root, path, body)
    full = File.join(root, path)
    FileUtils.mkdir_p File.dirname(full)
    File.write full, body
    FileUtils.chmod 0o755, full
  end
end
