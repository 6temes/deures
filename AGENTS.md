# AGENTS.md

Deures is a self-hosted Rails app that two children open on their own iPads to answer
the maths cards due that day. They see the study screen and nothing else: there is no
parent screen, no admin screen, and no menu anywhere in the app. You are the whole
administration surface, and you reach it from the console.

## This Repository Is Published

Deures is open source. Every commit is permanent and world-readable, and `git rm --cached`
in a later commit takes nothing back out of the history — only a rewrite does, and a rewrite is
only possible before the first push. So the check happens before the commit, not after it.

`bin/secrets_guard` is that check. It runs as a pre-commit hook, which `bin/setup` installs by
pointing `core.hooksPath` at `.githooks`, and again over every tracked file in `bin/ci`. It
refuses a commit that carries:

- a key of any kind: `config/master.key`, `config/credentials/*.key`, `.pem`, an SSH private
  key, a `known_hosts`
- an environment file, which on the server holds the master key and the backup host's login
- a database, a log, anything under `tmp/`, and anything under `.claude/`
- a private key block, a cloud or service token, or credentials inside a URL

If it refuses something, take the file out of the commit rather than out of the working tree:
`git restore --staged <path>`. Adding a rule exception means editing `bin/secrets_guard` and saying
in the diff why the file is safe.

What the gate cannot see, and you have to:

- **No local paths.** Never write a home directory or a checkout path into a file here — not in
  a comment, a plan, a commit message, or a README. Name the thing, not where it sits on one
  machine.
- **No real household values.** The backup host, its user, the app's domain, and the SSH paths
  appear in the README as placeholders. Keep them placeholders.
- **A pairing link is a credential.** `Ops::Devices::IssueLink` prints one that signs an iPad in
  as a child with no further check. It belongs in the terminal that printed it, never in a
  commit, an issue, a test fixture, or a screenshot.

## Commands

```bash
bin/setup                      # install dependencies, prepare the database
bin/dev                        # development server
bin/rails test                 # unit and integration tests
bin/rails test:system          # browser tests
bin/standardrb --fix           # Ruby style, with autocorrect
bin/annotaterb models          # rewrite the schema comment on each model, test, and fixture
bin/ci                         # the gate: style, security, tests, seeds. Run before merging
bin/ci style                   # one group of it — style, security, tests, or system
bin/secrets_guard              # refuse a commit that carries a key, a database, or a log
bin/rails runner 'Ops.help'    # every operation, with a working example of each
```

In the console, `ops` prints that same listing, and `help` lists it under Deures.

## Operations Are The Only Path

Every read and write of this app's data goes through an operation in
`app/operations/ops/`. This is the rule the project is built around.

- Never create, update, or destroy a record from the console by hand. No `Card.create!`,
  no `child.update!`, no `deck.destroy`.
- Never use `update_column`, `update_columns`, `update_all`, `delete_all`, `insert_all`,
  `upsert_all`, or raw SQL. Every one of them walks past the validations and callbacks the
  operations depend on.
- Attempts are append-only. Never edit or delete one, whatever the reason. `Attempt`
  refuses it in Ruby and nothing beneath that refuses it at all — there are no database
  triggers, deliberately — so `update_column` on an attempt would quietly succeed. That it
  is possible is not permission.
- Answer questions with the read operations rather than with a query you compose on the
  spot. An ad-hoc query is a number nobody can reproduce tomorrow.
- A question no operation answers, or a change no operation makes, is a missing operation.
  Write it, register it, test it, then run it. Working around it from the console is the
  one thing this rule exists to prevent.

## Writing An Operation

One class per operation under `app/operations/ops/`, grouped into a file per subject
(`cards.rb`, `children.rb`, `reads.rb`). Subclass `Ops::Base` and declare the operation:

```ruby
module Ops
  module Cards
    class Retire < Ops::Base
      operation name: "cards.retire",
        description: "Retire a card, keeping every child's progress and attempts.",
        example: %(Ops::Cards::Retire.call deck: "Addition to 100", prompt: "23 + 19")

      def initialize(deck:, prompt:)
        @deck, @prompt = deck, prompt
      end

      def perform
        # ...
        "23 + 19 retired from Addition to 100"
      end
    end
  end
end
```

- Keyword arguments only, and name a child by name, never by id: an invocation has to fit
  on one line typed on a phone.
- The declared example has to run against the fixtures exactly as written. A test executes
  every one of them.
- Implement `perform` and leave the rest alone. The base class runs it in the household
  time zone and in a transaction, prints what it returns, and hands back a result whose
  `inspect` is short so the console does not echo the summary a second time.
- A write returns one line, before and after: `"decks 2 → 3"`. A read returns the lines it
  wants printed.
- Declare `confirm: true` on an operation that changes many rows at once. Without
  `confirm: true` it does the whole job, prints it as a plan, and rolls it back, so the
  plan is the summary the confirmed run will print rather than a second guess at it. It is
  never an interactive prompt: a prompt hangs under `bin/rails runner` and holds SQLite's
  write lock while the children are answering.
- Refuse with `refuse!`, and say what to do instead.

## Dates

Every date is the calendar date in the household's time zone, which is a row on
`Household` and not `config.time_zone`. Take it from `Date.current` inside
`Household.with_zone`, never from `Date.today`, `date('now')`, or `CURRENT_DATE`: the
server clock is UTC and names yesterday for the first nine hours of every Tokyo day. The
base class already wraps every operation in that block.

## House Style

Architecture decisions here are all answered the same way: prefer what the framework and the
domain already give you to anything you would have to introduce. In practice that is five
habits.

Behaviour belongs to the object that owns the data — rich models with real names and bang
methods, never a service object, a manager, or a helper holding a verb that should have been
a method; a concern carries what is genuinely shared sideways.

A custom controller action is a missing noun, so create the resource it implies. The noun you
are forced to name is almost always a concept the domain was missing.

State lives in records rather than boolean columns, because a record carries when and by whom
for free, and a boolean throws both away.

Use the method Rails already ships before writing one, and write one before reaching for a
gem. The failure to watch for is not broken code but plausible code that reimplements
something the framework has had for years.

The app runs on SQLite on a single home server, with no job backend and no external services.
A proposal that changes that has to earn it rather than assume it — most of them are a way of
avoiding the first four habits rather than a need.

- Minitest with fixtures; `test/` mirrors `app/`.
- The operations in `app/operations/ops/` are the only classes here that are not a model, a
  view, or a controller. That is the one exception, and it is not a precedent.
- Standard, with the Rails cops, and no house rules beyond the two exemptions `.standard.yml`
  states.
- Alphabetical ordering for associations, validations, enum values, and hash keys, where
  it reads better.
