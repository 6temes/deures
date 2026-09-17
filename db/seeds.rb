# The household's launch state, and the one path Pau's first deck reaches the database by:
# the operations the agent runs at the console, and nothing else. No pairing link is seeded.
# A link is a credential, and Ops::Devices::IssueLink prints one when an iPad is paired.

# Every operation opens in the household's time zone, so this row has to exist before the
# first of them runs. Nothing creates it: Ops::Households::SetTimeZone changes the zone on it.
Household.first || Household.create!(time_zone: "Asia/Tokyo")

[["Pau", "blue", 10, 5], ["Teo", "green", 10, 3]].each do |name, color, threshold, cap|
  next if Child.exists?(name:)

  Ops::Children::Create.call(name:, color:)
  Ops::Children::SetPace.call(child: name, threshold:, cap:)
end

deck = "Addition to 100"

# The order of these two hashes is the order Pau meets the cards in: whole tens, then a
# one-digit addend, then two two-digit numbers, then the same with carrying, and last the
# pairs that make 100. New cards are admitted in that order as well, so a card inserted
# anywhere but the end moves every card after it to a later day.
opening = {
  "20 + 30" => "50",
  "40 + 20" => "60",
  "50 + 30" => "80",
  "60 + 10" => "70",
  "30 + 30" => "60",
  "70 + 20" => "90",
  "23 + 4" => "27",
  "41 + 6" => "47",
  "52 + 7" => "59",
  "64 + 5" => "69",
  "75 + 3" => "78",
  "86 + 2" => "88"
}

rest = {
  "13 + 45" => "58",
  "23 + 15" => "38",
  "31 + 24" => "55",
  "42 + 36" => "78",
  "54 + 22" => "76",
  "61 + 27" => "88",
  "27 + 5" => "32",
  "38 + 6" => "44",
  "46 + 8" => "54",
  "55 + 9" => "64",
  "68 + 7" => "75",
  "79 + 4" => "83",
  "23 + 19" => "42",
  "34 + 29" => "63",
  "38 + 27" => "65",
  "45 + 26" => "71",
  "47 + 35" => "82",
  "56 + 18" => "74",
  "58 + 24" => "82",
  "62 + 29" => "91",
  "12 + 88" => "100",
  "26 + 74" => "100",
  "35 + 65" => "100",
  "45 + 55" => "100",
  "60 + 40" => "100",
  "72 + 28" => "100",
  "83 + 17" => "100",
  "51 + 49" => "100"
}

unless Deck.exists?(name: deck)
  Ops::Decks::Create.call name: deck
  # Assigning before the cards are added is what makes the opening batch due: due_today
  # writes onto the progress rows an assignment creates, and an unassigned deck has none.
  Ops::Decks::Assign.call(child: "Pau", deck:, confirm: true)
  Ops::Cards::Add.call(deck:, cards: opening, due_today: true, confirm: true)
  Ops::Cards::Add.call(deck:, cards: rest, confirm: true)
end
