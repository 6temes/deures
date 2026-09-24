# Runbook

The one-time and occasional operations for running Deures for a household: bringing the database
into being, pairing an iPad, and proving the backup is a backup.

[README.md](README.md#running-it-for-real) says what a deployment has to provide, and
[AGENTS.md](AGENTS.md) is the rule book for the operations themselves.

## The first boot

The server refuses to boot unless the database it finds has tables in it, rather than creating an
empty one: a seeded database replicated over the children's history is the one failure a backup
cannot undo. A zero-byte file is a valid empty SQLite database, so a restore that left one behind
is refused exactly as an absent file is. So the first deploy of all creates the database once, by
hand, before the server first starts:

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
comes back as that child with nothing to tap. The link expires fifteen minutes after it is
issued and pairs the one iPad that opens it, so issue it with that iPad in hand and issue a
second one for a second iPad. After that the iPad is signed in by its own cookie, and the
installed icon opens the app itself rather than the link.

One operation signs an iPad out:

```ruby
Ops::Devices::Forget.call child: "Pau", confirm: true
```

It signs out every iPad that child has signed in, not a chosen one, and each shows the
lost-identity screen from then on. The icon stays where it is: issue a fresh link, open it on the
iPad, and the icon is that child's again with nothing to install. The rows stay with their
last-seen stamps, so it is still possible to tell which iPad was which.

It is also the one to reach for when a device has to stay out, and it is enough on its own: the
only way back in is a link opened on the iPad, and a link is good for fifteen minutes and for the
one iPad that opens it.

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

## The iPad app

The app in `ios/` shows the same study screen, and adds a gate: on a school day, until that
child's day is done, Screen Time shields every app on the iPad but Deures and the few the parent
allows. It replaces the Home Screen icon from [Pairing an iPad](#pairing-an-ipad). The pairing code
is the same one, and on an iPad with the app the camera opens the app with it rather than Safari.

### Before the first install

Family Controls, the framework the gate is built on, needs a paid Apple Developer Program
membership. A free account cannot sign an app that uses it.

The household's values live in `ios/Config/Local.xcconfig`, which is git-ignored and which
`bin/secrets_guard` refuses. Copy `ios/Config/Local.example.xcconfig` to it and fill in the Team
ID, a bundle prefix of your own, and `APP_HOST`. That host has to be exactly the one
`Ops::Devices::IssueLink` prints links for, or the app will not take a pairing link. Signing reads
the team from that file, so there is nothing to set on Xcode's Signing screen.

The server has to be serving the association file before the first pairing: set `APPLE_APP_ID`
in the deployment, as the [README](README.md#running-it-for-real) says, to the Team ID, a dot,
and `<BUNDLE_ID_PREFIX>.deures`. Without it the pairing code opens Safari.

### Installing

On the child's iPad, signed in to the child's Apple Account, turn on Settings › Privacy & Security
› Developer Mode, which restarts it. Connect it to the Mac, choose it as the destination of the
Deures scheme, and run. Then turn on Settings › Developer › Associated Domains Development. A
development build asks for its association with `?mode=developer`, which the iPad honours only
with that switch on, and it then fetches the file from the server itself.

A development install stops opening when its signing expires, a year after it was signed. Run it
from Xcode again before then, over the top of the installed app rather than after deleting it, so
the setup and the pairing are kept.

### Setting it up

The first launch asks for Screen Time permission, which the parent approves with their own Apple
Account. Then it asks for the PIN, twice, then for the allowed apps, and last for the pairing
code, which is scanned with the Camera like any other. Pick individual apps rather than
categories: a shield over every category cannot exempt a whole category. Apple caps the list at 50
apps, and the picker will not save more.

Then, on the iPad:

- **Set a Screen Time passcode** in Settings › Screen Time, if it has none. It is what stops a
  child deleting the app or turning off its Screen Time access. Turning that access off lifts
  every shield at once and the app cannot put one back, which makes it the one exception to
  blocking by default; while it is off, the app shows an "ask a grown-up" screen.
- **Keep Downtime for bedtime, and turn App Limits off.** Downtime is Apple's own and the gate
  leaves it alone. App Limits shield apps too, and with them on, a shielded app during the day is
  no longer the gate's doing.
- **Delete the old Home Screen icon.**

The iPad is gated from the next school day.

### The PIN

Choose six digits that are not the Screen Time passcode, enter them where the child cannot see,
and change the PIN if a child may have seen it. Holding the top-left corner of the study screen for three
seconds, or the lock button on the not-paired and error screens, asks for it, and behind it are Unlock for
today, Change allowed apps and Change PIN. Wrong guesses lock the prompt for longer each time.

An iPad that is already paired asks for the PIN before it takes another pairing code, so a child
cannot scan a sibling's code to reach a day that is already done.

A forgotten PIN is recovered in Settings, not in the app. Turn Deures's Screen Time access off in
Settings › Screen Time, behind the Screen Time passcode, which lifts the gate. Turning it back on
is a fresh approval, and that lets setup set a new PIN.

### Holidays

Weekends are free days, and so are the public holidays of the household's country, which is Japan
until it is changed:

```ruby
Ops::Households::SetHolidayCountry.call country: "es"
```

The app reads the free days from `GET /day`, so an iPad picks up the change the next time it
opens Deures.

### The drills

No part of the gate can be tested off a real iPad, so these are the proof that it works. Run them
on a child-account iPad before either child is handed one, in this order.

D1 and D2 are the stop conditions. If either fails, stop: the gate cannot work on these iPads as
designed, and that goes back to the parent as a decision rather than being fixed in the app. Both
run before setup, from Xcode with the launch argument `-DeuresProbe YES` in the scheme's Run
arguments, which opens a debug-only probe in place of the app.

- **D1.** Install from Xcode with Developer Mode on, and grant `.child` authorization. Stop if
  either fails. In the probe, Request child authorization, and the status has to read approved.
- **D2.** Pick an allowlist with Messages and one game, and leave the day pending. The game opens,
  every other app shows the shield, and Deures opens and its study page loads and takes an answer.
  Stop if the allowlisted game is shielded too (Apple's open defect FB15500605). If only the study
  page is blocked, change the shield to cover app categories only, which still blocks Safari and
  every other browser, and repeat. In the probe, Pick the allowlist, then Shield all except picked.
  For the study page, run again without the launch argument and pair: until setup is completed the
  app leaves the probe's shield as it is. Clear lifts it afterwards.
- **D8.** As the child, try to change the date, the time zone, and Set Automatically, and try to
  delete, offload or revoke Deures. Every attempt should be refused. If the date can be changed,
  record it: an offline jump to a free day is then an accepted risk.
- **D3.** Finish the day's cards. The shield lifts when the done screen appears. Then enter the
  PIN on a new pending day, and the shield lifts.
- **D4.** Force-quit, reboot and go offline on a pending school day. The shield stays.
- **D5.** Leave the iPad unused overnight after an unlocked day, then open it on a school morning.
  The shield is back.
- **D6.** Excuse the day from the console, with `Ops::Relief::Excuse`, then open Deures. The
  shield lifts.
- **D7.** Scan a fresh `IssueLink` code with the Camera on an unpaired app. The app opens and
  pairs, and Safari does not open.
- **D9.** Scan the other child's code on a gated, paired iPad. The PIN prompt appears, and the code
  is not used.
