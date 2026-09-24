require "test_helper"
require "open3"
require "tmpdir"

# The gate is the one check with no second line of defence: nothing downstream notices a key
# that reached a public history. So it is drilled in a throwaway repository rather than
# against this one's index, which a test must never stage into.
class SecretsGuardTest < ActiveSupport::TestCase
  GATE = Rails.root.join("bin/secrets_guard").to_s

  test "refuses a staged key file" do
    refused = stage("config/credentials/production.key" => "b0a1c2d3e4f5")
    assert_includes refused, "config/credentials/production.key"
    assert_includes refused, "decrypts the credentials"
  end

  test "refuses a staged environment file" do
    assert_includes stage(".env" => "RAILS_MASTER_KEY=b0a1c2d3e4f5\n"), ".env"
  end

  test "refuses a staged database, log, and bootsnap cache" do
    %w[storage/production.sqlite3 log/production.log tmp/cache/bootsnap/x].each do |path|
      assert_includes stage(path => "x"), path
    end
  end

  # Each probe is split across two source lines, because the gate reads a file a line at a
  # time and this file would otherwise trip it. Exempting the test instead would put a hole
  # in the one check nothing downstream backs up.
  test "refuses a private key block whatever the file is called" do
    body = "-----BEGIN OPENSSH " \
           "PRIVATE KEY-----\nabc\n"
    assert_includes stage("app/models/innocent.rb" => body), "a private key block"
  end

  test "refuses credentials carried inside a URL" do
    body = %(replica "sftp://backup:hunter2) +
      %(@10.0.0.2:22/db")
    assert_includes stage("config/storage.yml" => body), "credentials inside a URL"
  end

  # The secret is in the index, which is what the commit will carry; the working tree has been
  # cleaned up since. Reading the file rather than the staged blob would allow it.
  test "refuses a secret staged and then edited out of the working tree" do
    key = "AKIA" + "IOSFODNN7EXAMPLE"
    refused = stage("config/storage.yml" => "access_key_id: #{key}\n") do
      File.write "config/storage.yml", "access_key_id: <%= ENV[\"AWS_KEY\"] %>\n"
    end

    assert_includes refused, "an AWS access key id"
  end

  test "refuses a staged Local.xcconfig and names the file" do
    refused = stage("ios/Config/Local.xcconfig" => "APP_HOST = example.test\n")
    assert_includes refused, "ios/Config/Local.xcconfig"
    assert_includes refused, "household"
  end

  test "passes the committed xcconfig template" do
    assert_nil stage("ios/Config/Local.example.xcconfig" => "APP_HOST = \n")
  end

  test "refuses a Team ID written into the Xcode project by the Signing screen" do
    refused = stage("ios/Deures.xcodeproj/project.pbxproj" => "\t\t\t\tDEVELOPMENT_TEAM = ABCDE12345;\n")
    assert_includes refused, "project.pbxproj:1"
    assert_includes refused, "Team ID"
  end

  test "refuses a Team ID written under the target attributes of the Xcode project" do
    refused = stage("ios/Deures.xcodeproj/project.pbxproj" => "\t\t\t\t\t\tDevelopmentTeam = ABCDE12345;\n")
    assert_includes refused, "project.pbxproj:1"
    assert_includes refused, "Team ID"
  end

  test "refuses a Team ID in an xcconfig, quoted or not" do
    assert_includes stage("ios/Config/Base.xcconfig" => "DEVELOPMENT_TEAM = ABCDE12345\n"), "Team ID"
    assert_includes stage("ios/Config/Base.xcconfig" => %(DEVELOPMENT_TEAM = "ABCDE12345";\n)), "Team ID"
  end

  test "passes an empty or indirect Team ID" do
    assert_nil stage(
      "ios/Deures.xcodeproj/project.pbxproj" => %(DEVELOPMENT_TEAM = "";\n),
      "ios/Config/Base.xcconfig" => "DEVELOPMENT_TEAM = $(TEAM_ID)\n"
    )
  end

  test "passes a Team ID line outside the Xcode project files" do
    assert_nil stage("README.md" => "    DEVELOPMENT_TEAM = ABCDE12345\n")
  end

  test "passes a commit that carries none of them" do
    assert_nil stage("app/models/card.rb" => "class Card < ApplicationRecord\nend\n")
  end

  test "passes the .keep files Rails tracks to carry an empty directory" do
    assert_nil stage("tmp/pids/.keep" => "", "log/.keep" => "")
  end

  private

  # Stages the given files in a fresh repository and runs the gate over them. Returns what it
  # refused, or nil when it allowed the commit.
  def stage(files)
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        system "git init --quiet .", exception: true

        files.each do |path, body|
          FileUtils.mkdir_p File.dirname(path)
          File.write path, body
        end
        system "git", "add", "-f", "--", *files.keys, exception: true
        yield if block_given?

        # [command, argv0], because this checkout's own path has a space in it and Ruby
        # splits a bare command string on whitespace before exec'ing it.
        output, status = Open3.capture2e([GATE, GATE])
        status.success? ? nil : output
      end
    end
  end
end
