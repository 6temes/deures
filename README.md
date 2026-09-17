<img src=".github/mark.svg" alt="" width="88">

# Deures

*Deures* is Catalan for homework.

Pau and Teo each open this on their own iPad and answer the maths cards due that day on an
in-app number pad, until they reach the done screen. It is installed from Safari to the Home
Screen, comes up already signed in as that child on every launch, and has no parent screen, no
admin screen, and no menu anywhere.

<img src=".github/palette.svg" alt="The seven child colours" width="386">

Each child owns one of those colours. It paints their typed digits, their submit key, their
stars and their pairing card, and their Home Screen icon is that colour and nothing else — which
is how two iPads on the same table are told apart.

The administration surface is the console: every read and write of the app's data is an
operation in `app/operations/ops/`. [AGENTS.md](AGENTS.md) is the rule book for that, and it is
the first thing to read before changing anything here.

## Development

Ruby, as `.ruby-version` names it, and Node, as `.nvmrc` does. Node is not part of the app —
there is no build step and no JavaScript dependency at runtime — but the ERB linter is a Node
program, so `bin/ci` needs it.

```bash
bin/setup                      # dependencies and the database
bin/dev                        # development server
bin/ci                         # the gate: style, security, tests, seeds. Run before merging
bin/ci style                   # one group of it — style, security, tests, or system
bin/secrets_guard              # refuse a commit that carries a key, a database, or a log
bin/rails runner 'Ops.help'    # every operation, with a working example of each
```

## Deployment

Deployment is not configured here. The infra repository owns it — the Kamal configuration, the
proxy, the backups, and the host — and this repository holds only the `Dockerfile` that builds
the image and the entrypoint that boots it.

What the app needs from any deployment:

| What | Why |
|---|---|
| `RAILS_MASTER_KEY` | Decrypts the credentials. The app will not boot in production without it. |
| A persistent volume at `/rails/storage` | `production.sqlite3` lives there and is the whole of the app's state. |
| A database file in that volume before the server starts | The entrypoint refuses to boot without one rather than creating an empty one — see below. |
| Continuous replication of that file off the host | The volume is one disk, and every card, schedule and attempt is on it. |
| TLS, the original `Host` header, and the forwarded-proto header | The app builds the pairing URL from the host it is reached on. |

### The first boot

The server refuses to boot when there is no database file, rather than creating an empty one: a
seeded database replicated over the children's history is the one failure a backup cannot undo.
So the first deploy of all creates the database once, by hand, before the server first starts:

```bash
bin/rails db:prepare
```

Every deploy after that finds the file the volume or a restore left, and migrates it.

### The console

Give the server a host alias in `~/.ssh/config` on the machine the agent runs from, so nothing
has to remember an address:

```sshconfig
Host study
  HostName <address>
  User <user>
```

Then:

```bash
ssh study
tmux new -A -s deures
```

and open a Rails console in the running container. Every command from here on runs in there, and
is written below as the `bin/rails` command itself; the invocation that reaches the container
belongs to the deployment, so the infra repository is where it is written down.

Run it inside tmux. A console on a phone loses its connection sooner or later, and an operation
that was half-way through a transaction when that happens is worth being able to walk back into;
`tmux new -A -s deures` re-attaches to the same session rather than opening a second one. In
the console, `ops` lists every operation. Outside it,
`bin/rails runner 'Ops.help'` prints the same listing.

### The first seed

`db/seeds.rb` is the household's launch state: the household in Asia/Tokyo, Pau (blue, threshold
10, cap 5), Teo (green, threshold 10, cap 3), and Pau's first deck. It authors that deck through
`Ops::Decks::Create`, `Ops::Decks::Assign` and `Ops::Cards::Add` and no other path, which is why
the deck is a seed file rather than a transcript to paste: `bin/ci` runs the seeds on every build,
so content the operations would refuse fails there rather than at the console on the day the iPads
are handed over. Run it once, after the first deploy:

```bash
bin/rails db:seed
```

"Addition to 100" is 40 cards in teaching order — whole tens, then a one-digit addend, then two
two-digit numbers, then the same with carrying, and last the pairs that make 100 — of which the
first twelve are due on the day the seed runs, so Pau's first session is a session rather than the
five new cards his daily cap would otherwise allow. The rest arrive five a day, on any day that
starts with fewer than ten cards already due. Every step skips what is already there, so running
the seeds again changes nothing. Teo has no deck yet; his is authored from the console with those
same three operations.

Never run `db:seed:replant` on the server. It purges every table before it seeds, the attempt log
included. It is the form CI runs, against a database that is thrown away afterwards.

Then read back what landed:

```ruby
Ops::Reads::Status.call
Ops::Reads::Forecast.call child: "Pau"
```

### Pairing an iPad

Issue the link from the console, which prints it as a code the iPad camera reads:

```ruby
Ops::Devices::IssueLink.call child: "Pau"
```

Point the camera at the code, open it in Safari, then Share and Add to Home Screen. The icon
comes up in the child's color. Force-quit the app and reopen it from the icon to confirm it
comes back as that child with nothing to tap. A link never expires and can be opened on as many
devices as needed.

Two operations sign an iPad out, and they are not interchangeable:

```ruby
Ops::Devices::Forget.call child: "Pau", confirm: true      # signs the iPads out, keeps the icon working
Ops::Devices::RevokeLink.call child: "Pau", confirm: true  # kills the link, and the icon with it
```

Forgetting leaves the pairing link live, so the icon already on the Home Screen pairs that iPad
again at the next launch: Pau taps it and his question is there, with nothing to install and
nothing to tap. That is the re-pair drill — run it on a handover day to prove an iPad that has
been shut in a drawer for weeks still heals itself. It forgets every device that child has
signed in, not a chosen one, and the rows stay with their last-seen stamps, so it is still
possible to tell which iPad was which.

Revoking takes the link with it, which is the one to reach for when a device has to stay out:
every iPad that used that link shows the lost-identity screen until a new link is issued and
added to the Home Screen again.

### The restore drill

Whatever replicates the database, the drill is the same, and it is the only proof that a backup
is a backup. Run it before either child is handed the app, and again after any change to the
services, the volume, or the replication settings: destroy the volume, bring the app back, and
run

```ruby
Ops::Reads::Status.call
```

It has to print the children and where they are today. If the server will not start, or the
listing comes back empty, the restore did not put the database back — and the replicator must
not be allowed to run against a database the restore did not write, because it will copy that
one over the real history.

## What each loss costs

### The master key

`config/master.key` decrypts the credentials, and the app cannot boot in production without it:
the container will restart and the proxy will have nothing to reach. It does not sign the iPads
out. The pairing cookie is an opaque token checked against the `devices` table, neither signed
nor encrypted, so it survives a new `secret_key_base` — which is exactly why it is written that
way. Recovery is to put the key back, or, if it is gone for good, to write new credentials and
redeploy. The children notice nothing.

### The database

Losing the volume is what replication is for, and the drill above is the rehearsal.
Losing the volume *and* the replica is different: the device rows are the identity of record, so
both iPads are signed out, and every card, schedule, and attempt is gone with them. Recovery is
to issue a new pairing link for each child and add the app to the Home Screen again on each
iPad. Reopening the icon that is already there cannot re-pair it: the installed start URL
carries the old token, and that token no longer exists.

## License

[MIT](LICENSE). Use it, change it, run it for your own household.
