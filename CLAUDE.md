# CLAUDE.md

**This repository is public.** Every commit you make is world-readable the moment it is
pushed, and permanent after that: `git rm --cached` in a later commit takes nothing back
out of the history. So the check happens before the commit, not after it. `bin/secrets_guard`
runs as a pre-commit hook and over every tracked file in `bin/ci`, but it can only see the
file types it knows — what it cannot see, and you have to, is in AGENTS.md under
[This Repository Is Published](AGENTS.md#this-repository-is-published): no local paths, no
real household values, and never a pairing link, which signs an iPad in as a child.

The rest of this project's instructions for agents are in [AGENTS.md](AGENTS.md). Read that
file first: it is the same file for every agent, and it carries the rule that matters most
here, which is that every read and write of this app's data goes through an operation in
`app/operations/ops/`.
