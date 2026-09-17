# Run using bin/ci, optionally with one group name: bin/ci style.
#
# The steps stay in this one file, because config/ci.rb is the gate AGENTS.md names and a check
# added there has to be a check a pull request runs. The groups are only a way to spread them
# over parallel GitHub jobs: the workflow asks `bin/ci --groups` what they are called rather
# than carrying a list of its own, so there is no second list to drift from this one.

GROUPS = {
  "style" => [
    ["Style: Ruby", "bin/standardrb"],
    # Every template this app owns is a view or one of the four static error pages; the paths are
    # named because herb walks the tree it is given and does not read .gitignore, so a design
    # bundle or a plan under `docs/` would otherwise be linted as if it were ours.
    #
    # An argument is also load-bearing for anyone whose checkout path contains a space: the herb
    # gem execs the linter as a one-element array, and Ruby splits a lone command string on
    # whitespace, so the path is truncated at the first space. Any argument takes the other branch.
    ["Templates: ERB", "bin/herb analyze app public"],
    ["Style: ERB", "bin/herb lint app public"],
    ["Style: JavaScript", "bin/eslint --ci"],
    ["Style: Formatting", "bin/prettier --ci"],
    ["Schema: Annotations match the tables", "bin/annotaterb models --frozen"]
  ],
  "security" => [
    ["Security: Secrets", "bin/secrets_guard --tracked"],
    ["Image: Ruby version", "bin/dockerfile_guard"],
    ["Security: Importmap vulnerability audit", "bin/importmap audit"],
    ["Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"]
  ],
  "tests" => [
    ["Schema: Constraints behind the validations", "bin/database_consistency"],
    ["Routes: Nothing unreachable", "bin/traceroute"],
    ["Tests: Rails", "bin/rails test"],
    ["Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"],
    ["Tests: Operations load outside the console", "bin/rails runner 'Ops.help'"]
  ],
  "system" => [
    ["Tests: System", "bin/rails test:system"]
  ]
}

if ARGV.include?("--groups")
  require "json"
  puts JSON.generate(GROUPS.keys)
  exit
end

WANTED = ARGV.find { !it.start_with?("-") }
abort "No CI group called #{WANTED}. There are: #{GROUPS.keys.join(", ")}" if WANTED && !GROUPS.key?(WANTED)

CI.run do
  step "Setup", "bin/setup --skip-server"

  GROUPS.each do |name, steps|
    next if WANTED && name != WANTED

    steps.each { |title, *command| step title, *command }
  end
end
