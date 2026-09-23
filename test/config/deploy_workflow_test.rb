require "test_helper"

# The deploy workflow cannot be exercised here: its acceptance run is the first deploy after it
# merges. What can be asserted is the shape nothing downstream would report — an unpinned action
# is a third party's later commit running with this repository's deploy key, a failing step
# allowed to continue is a deploy that reports success without having happened, and the preflight
# is what stops an empty bind address publishing the metrics ports on every interface.
class DeployWorkflowTest < ActiveSupport::TestCase
  WORKFLOW = Rails.root.join(".github/workflows/deploy.yml")
  CONTENTS = WORKFLOW.read

  test "pins every action to a full commit sha" do
    unpinned = CONTENTS.scan(/^\s*uses:\s*(\S+)/).flatten.reject { it.split("@").last.match?(/\A[0-9a-f]{40}\z/) }

    assert_empty unpinned, "deploy.yml runs #{unpinned.join(", ")} from a mutable ref"
  end

  test "lets no step continue past its own failure" do
    assert_nil CONTENTS[/continue-on-error/], "deploy.yml lets a step continue past its own failure"
  end

  test "checks the required secrets before reaching the server" do
    job = YAML.load(CONTENTS, aliases: true).dig("jobs", "deploy")

    assert_equal "Preflight required secrets", job["steps"].first["name"]
  end

  # The list in the preflight loop is a second copy of the job's own environment, so the two drift
  # apart silently: a secret added to one and not the other is exactly the empty value the step
  # exists to catch, and it would reach kamal unchecked.
  test "preflights every secret the job carries" do
    job = YAML.load(CONTENTS, aliases: true).dig("jobs", "deploy")
    checked = job["steps"].first["run"][/for var in ([^;]+);/, 1].split
    carried = job["env"].keys - ["DEPLOY_SHA"]

    assert_empty carried - checked, "deploy.yml carries secrets its preflight never checks"
  end

  # The trigger is a workflow_run of a CI workflow that itself runs on pull_request, in a public
  # repository: without both of these the job would run a fork's own commit, in this repository's
  # context, with the deploy key and the master key loaded.
  test "refuses a run that did not come from a push to this repository" do
    condition = YAML.load(CONTENTS, aliases: true).dig("jobs", "deploy", "if")

    assert_includes condition, "workflow_run.event == 'push'"
    assert_includes condition, "workflow_run.head_repository.full_name == github.repository"
  end

  test "names no address, household domain, server directory or login of its own" do
    addresses = CONTENTS.scan(/\b\d{1,3}(?:\.\d{1,3}){3}\b/) - ["0.0.0.0"]
    assert_empty addresses, "deploy.yml names #{addresses.join(", ")}"

    %w[6temes /srv/ daniel].each do |literal|
      assert_not_includes CONTENTS, literal, "deploy.yml names #{literal}"
    end
  end
end
