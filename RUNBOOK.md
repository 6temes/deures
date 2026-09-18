# Runbook

The one-time and occasional operations for running Deures for a household: bringing the database
into being, pairing an iPad, and proving the backup is a backup.

[README.md](README.md#running-it-for-real) says what a deployment has to provide, and
[AGENTS.md](AGENTS.md) is the rule book for the operations themselves.

## The first boot

The server refuses to boot when there is no database file, rather than creating an empty one: a
seeded database replicated over the children's history is the one failure a backup cannot undo.
So the first deploy of all creates the database once, by hand, before the server first starts:

```bash
bin/rails db:prepare
```

That creates it, migrates it, and — because it created it — loads `db/seeds.rb` as well, so the
household exists from this one command. Every deploy after that finds the file the volume or a
restore left and only migrates it.

## The console

Every operation below runs in a Rails console on the host, and is written as the `bin/rails`
command itself. How you reach that console — and the invocation that gets into the running
container — belongs to the deployment, so the infra repository is where that is written down.

Use whatever keeps the session alive across a dropped connection. An operation that was half-way
through a transaction when the link died is worth being able to walk back into, and that matters
most on the device you are least likely to be at a desk with.

In the console, `ops` lists every operation. Outside it, `bin/rails runner 'Ops.help'` prints the
same listing.

## What the seeds put there

The first boot above already loaded them. `db/seeds.rb` is the household's launch state: the
household in Asia/Tokyo, Pau (blue, threshold 10, cap 5), Teo (green, threshold 10, cap 3), and
Pau's first deck. It authors that deck through `Ops::Decks::Create`, `Ops::Decks::Assign` and
`Ops::Cards::Add` and no other path, which is why the deck is a seed file rather than a transcript
to paste: `bin/ci` runs the seeds on every build, so content the operations would refuse fails
there rather than at the console on the day the iPads are handed over. Every step skips what is
already there, so `bin/rails db:seed` is safe to run again and changes nothing.

"Addition to 100" is 40 cards in teaching order — whole tens, then a one-digit addend, then two
two-digit numbers, then the same with carrying, and last the pairs that make 100 — of which the
first twelve are due on the day the seed runs, so Pau's first session is a session rather than the
five new cards his daily cap would otherwise allow. The rest arrive at up to five a day: his cap
is 5 against a light-day threshold of 10, so a day opening with five or fewer cards due admits
five, a day opening with nine admits one, and a day already at ten admits none.

Teo has no deck yet; his is authored from the console with those same three operations.

Then read back what landed:

```ruby
Ops::Reads::Status.call
Ops::Reads::Forecast.call child: "Pau"
```

## Pairing an iPad

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

## The restore drill

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
