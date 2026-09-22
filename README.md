<div align="center">

<img src=".github/mark.svg" alt="" width="96">

# Deures

**A wordless maths drill two children open on their own iPads.**

<a href="LICENSE"><img alt="MIT" src="https://img.shields.io/badge/license-MIT-green"></a>
<a href=".github/workflows/ci.yml"><img alt="CI" src="https://github.com/6temes/deures/actions/workflows/ci.yml/badge.svg"></a>
<a href=".ruby-version"><img alt="Ruby" src="https://img.shields.io/badge/ruby-4.0-CC342D"></a>
<img alt="Rails" src="https://img.shields.io/badge/rails-8.1-D30001">
<img alt="SQLite" src="https://img.shields.io/badge/sqlite-one%20file-003B57">

<a href="#what-it-is">What it is</a>
◆ <a href="#a-session">A session</a>
◆ <a href="#how-the-cards-are-chosen">How the cards are chosen</a>
◆ <a href="#one-colour-per-child">Colours</a>
◆ <a href="#try-it">Try it</a>
◆ <a href="#development">Development</a>

</div>

## What it is

*Deures* is Catalan for homework.

Pau and Teo each open this on their own iPad, answer the maths cards that are due that day on an
in-app number pad, and reach a screen with their name on it. Then they are finished, and there is
nothing else in the app to do.

That last part is the design. It is installed from Safari to the Home Screen, comes up already
signed in as that child on every launch, and has **no parent screen, no settings, no menu and no
links** — because a screen a child can reach is a screen a child will reach. A child this age
cannot read `3 / 12` either, so no text in the app carries meaning: the day's progress is one star
per card, and the only thing to tap is a digit.

Everything a parent does — writing a deck, watching where a child is stuck, pairing an iPad —
happens in a Rails console, never in the app.

## A session

There are four screens, and a child moves between them by answering.

| | What the child sees |
|---|---|
| **The card** | One question, the number pad, and a row of stars — filled for the cards cleared so far, outlined for the ones still to come. |
| **Right** | The answer turns their colour and a star fills. The next card arrives. |
| **Wrong** | What they typed, struck through, and the right answer beside it — nothing red, no sound of its own, no timer. They copy it on the pad, digit by digit, and the last one reveals the next question. The card goes to the back of the day's queue, so it comes round again before the day is over. |
| **Done** | Their name, alone, and the star row grows and centres. Reopening the app the same day returns here. |

A card that is answered wrong three times in one day is **parked**: it stops coming round, the
day can still finish, and it is flagged for the parent to look at. Nothing tells the child off.

## How the cards are chosen

A **deck** is an ordered list of cards — "Addition to 100" is 40 of them, in teaching order:
whole tens, then a one-digit addend, then two two-digit numbers, then the same with carrying, and
last the pairs that make 100. A deck is assigned to a child, and from then on each child has
their own progress on each card.

### The ladder

Progress is a rung on a six-rung ladder. Answer a card right and it climbs one rung; the rung
decides how far out it comes back.

```text
rung   0        1       2       3       4        5        6
       │        │       │       │       │        │        │
due    new    +1 day  +2 days +4 days +8 days +16 days +32 days
       or a
       lapse
```

One wrong answer costs the whole ladder: the card drops to rung 0 and is due again tomorrow, so
the next correct answer earns one day again, exactly as on a card never seen before. Only a
card's **first** answer of the day moves it, so answering wrong and then right on the same day
does not both reset the card and promote it.

### The day

The day is assembled once, the first time the child opens the app that day:

1. **Everything due.** Every card whose due date has arrived or passed.
2. **New cards, but only onto a light day.** Enough to reach the child's new-card cap, or enough
   to fill the day to their light-day threshold, whichever is smaller. A day that is already
   heavy with reviews admits none.

Both the cap and the threshold are set per child, so how fast a child moves is a setting rather
than something the app decides. Whatever they are, the shape holds: a child back from a week away
meets their whole backlog and no new cards on top of it, and a child who is up to date gets a
short day of new ones.

The day is over when the queue is empty. Cards answered wrong go to the back of it, so they come
round again within the same day.

Because the schedule is per child and per card, two children can share a deck and be in
completely different places in it.

## One colour per child

<img src=".github/palette.svg" alt="The seven child colours" width="386">

Each child owns one of those seven. It paints their typed digits, their submit key, their stars,
and a wash of it tints the whole screen behind them. Their Home Screen icon is that colour and
nothing else — which is how two iPads on the same table are told apart, by a child who cannot
read the label under either.

## Try it

```bash
git clone https://github.com/6temes/deures.git
cd deures
bin/setup                                       # dependencies, database, and the seeds
bin/dev                                         # http://localhost:3000
```

There is no login form, so a fresh checkout has nothing to look at until a device is paired. Mint
a link for one of the seeded children and open it:

```bash
bin/rails runner 'puts "/p?token=" + Child.find_by!(name: "Pau").pairing_links.create!.plain_token'
```

Visit that path, then visit `/`. You are now that child, with twelve cards due and nothing to tap
but a digit. Answer them all to reach the done screen.

> **Prerequisites** Ruby as `.ruby-version` names it, Node as `.nvmrc` does, and a browser.
> Nothing else — no Redis, no Postgres, no build step, no API key.

## Development

One Rails app and one SQLite file. Plain CSS in a single stylesheet, Turbo and Stimulus over
importmap, and **no build step** — Node is not part of the app at all, but the ERB linter is a
Node program, so `bin/ci` needs it.

```bash
bin/setup                      # dependencies, database, and the seeds
bin/dev                        # development server
bin/ci                         # the gate. Run before merging
bin/ci style                   # one group of it — style, security, tests, or system
bin/rails runner 'Ops.help'    # every operation, with a working example of each
```

Every read and write of the app's data goes through an operation in `app/operations/ops/`, and
nothing reaches a model directly. [AGENTS.md](AGENTS.md) is the rule book for that, and it is the
first thing to read before changing anything here.

## Running it for real

Deployment is not configured here. This repository holds the `Dockerfile` that builds the image
and the entrypoint that boots it; what any deployment has to provide is:

| What | Why |
|---|---|
| `RAILS_MASTER_KEY` | Decrypts the credentials. The app will not boot in production without it. |
| A persistent volume at `/rails/storage` | `production.sqlite3` lives there and is the whole of the app's state. |
| A database file in that volume before the server starts | The entrypoint refuses to boot without one rather than creating an empty one — see the [runbook](RUNBOOK.md#the-first-boot). |
| Continuous replication of that file off the host | The volume is one disk, and every card, schedule and attempt is on it. |
| `APP_HOST`, the domain the app is reached on | It is the `config.hosts` allowlist, so without it production rejects every request; and it is the host `Ops::Devices::IssueLink` prints pairing links for. Both fall back to `study.example.com`. |
| TLS terminated in front of the app, with the `Host` header preserved | `force_ssl` and `assume_ssl` are both on, so the app trusts that it is behind HTTPS and does not need the forwarded-proto header — but the `Host` it receives has to match `APP_HOST`. |

The first boot, the first seed, pairing an iPad and the restore drill are in
[RUNBOOK.md](RUNBOOK.md).

## Contributing

This is one household's app, so it carries one household's assumptions — but it is MIT and it is
meant to be run and changed. To use it for your own children, fork it: `db/seeds.rb` is the launch
state to edit, and `Ops::Decks::Create` authors a deck of your own.

Issues and pull requests are welcome. `bin/ci` is the gate and it has to be green;
[AGENTS.md](AGENTS.md) says what the house rules are before you change anything.

## License

[MIT](LICENSE). Use it, change it, run it for your own household.
