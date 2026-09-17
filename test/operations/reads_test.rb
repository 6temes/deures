require "test_helper"

class ReadsTest < ActiveSupport::TestCase
  # 23:30 UTC on the 13th is 08:30 Tokyo on the 14th, the date every read in here calls today.
  setup { travel_to Time.utc(2026, 9, 13, 23, 30) }

  test "status shows a done time for a finished child and a remaining count for an unfinished one" do
    children(:teo).study_days.create! study_date: today,
      first_opened_at: Time.utc(2026, 9, 13, 23, 0), done_at: Time.utc(2026, 9, 13, 23, 20)

    out = read { Ops::Reads::Status.call }

    assert_includes out, "2026-09-14 Asia/Tokyo"
    assert_includes out, "Pau  2 left"
    assert_includes out, "Teo  done 08:20"
  end

  test "status warns for a child with more than thirty due" do
    child_with_due_cards name: "Sis", due: 31
    child_with_due_cards name: "Bob", due: 30

    out = read { Ops::Reads::Status.call }

    assert_match(/Sis  31 due, not opened  backlog/, out)
    assert_match(/Bob  30 due, not opened$/, out)
    assert_no_match(/Pau.*backlog/, out)
  end

  test "status counts what is due for a child whose day was excused before they opened the app" do
    child_with_due_cards name: "Sis", due: 31
    read { Ops::Relief::Excuse.call child: "Sis", reason: "sick" }

    out = read { Ops::Reads::Status.call }

    assert_match(/Sis  31 due, not opened  backlog/, out)
  end

  test "progress orders by lapses in the last thirty days, and a lapse outside the window does not count" do
    lapse! card: cards(:times_6_7), on: Date.new(2026, 9, 10)
    lapse! card: cards(:times_6_7), on: Date.new(2026, 9, 12)
    lapse! card: cards(:sum_23_19), on: Date.new(2026, 8, 1)

    out = read { Ops::Reads::Progress.call child: "Pau" }

    assert_equal ["6 × 7", "38 + 27", "7 - 7", "23 + 19"], prompts_in(out)
    assert_match(/2 lapses  rung 0  new           .*6 × 7/, out)
    assert_match(/0 lapses  rung 4  due 2026-09-14  23 \+ 19/, out)
  end

  test "progress shows a parked card with the typed answers beside the expected one, and stops showing it once answered correctly" do
    lapse! card: cards(:sum_38_27), on: Date.new(2026, 9, 13), answer: "56", index: 2
    lapse! card: cards(:sum_38_27), on: Date.new(2026, 9, 13), answer: "60", index: 3

    out = read { Ops::Reads::Progress.call child: "Pau" }

    assert_includes out, "parked 2026-09-13: 56, 56, 60 (want 65)"

    queue_items(:pau_sum_38_27).show!.answer! "65"

    assert_not_includes read { Ops::Reads::Progress.call child: "Pau" }, "parked"
  end

  test "the attempts average excludes an answer over one hundred and twenty seconds and marks it" do
    answered! card: cards(:sum_23_19), on: today, answer: "42", seconds: 2.0
    answered! card: cards(:times_6_7), on: today, answer: "42", seconds: 300.0

    out = read { Ops::Reads::Attempts.call child: "Pau", since: "2026-09-01" }

    assert_includes out, "Pau, 3 attempts since 2026-09-01, 1 wrong"
    assert_match(/2026-09-14  ok     away    6 × 7 = 42/, out)
    assert_match(/2026-09-13  wrong  4.2s    38 \+ 27 = 56/, out)
    assert_includes out, "average 3.1s over 2 answers, 1 walked away"
  end

  test "history shows done, excused, and missed days, and an excused day that was also done shows as done (AE6)" do
    day! on: Date.new(2026, 9, 10), done_at: Time.utc(2026, 9, 10, 9, 0)
    day! on: Date.new(2026, 9, 11), excused_at: Time.utc(2026, 9, 11, 9, 0), excuse_reason: "holiday"
    day! on: Date.new(2026, 9, 12), done_at: Time.utc(2026, 9, 12, 9, 0),
      excused_at: Time.utc(2026, 9, 12, 9, 0), excuse_reason: "holiday"

    out = read { Ops::Reads::History.call child: "Pau" }

    assert_includes out, "Pau, 2026-09-01 to 2026-09-13"
    assert_includes out, "2026-09-10  done"
    assert_includes out, "2026-09-11  excused (holiday)"
    assert_includes out, "2026-09-12  done"
    assert_includes out, "2026-09-13  missed"
    assert_includes out, "2 done, 1 excused, 10 missed"
    assert_not_includes out, "2026-09-14"
  end

  test "the forecast counts unseen cards and due cards per day for fourteen days in the household zone" do
    due_card! prompt: "9 + 9", position: 10, on: Date.new(2026, 9, 20)
    due_card! prompt: "8 + 8", position: 11, on: Date.new(2026, 10, 5)
    card_progresses(:pau_times_6_7).update! due_on: Date.new(2026, 9, 1)

    assert_equal Date.new(2026, 9, 13), Time.now.utc.to_date
    out = Time.use_zone("UTC") { read { Ops::Reads::Forecast.call child: "Pau" } }

    assert_includes out, "Pau, next 14 days"
    assert_match(/2026-09-14 Mon    3  today/, out)
    assert_match(/2026-09-20 Sun    1$/, out)
    assert_match(/2026-09-27 Sun    0$/, out)
    assert_not_includes out, "2026-09-28"
    assert_not_includes out, "2026-10-05"
    assert_includes out, "1 unseen card remaining"
  end

  test "a read of a child nobody has created is refused, and the refusal names the children there are" do
    refusal = assert_raises Ops::Base::Refused do
      read { Ops::Reads::Progress.call child: "Mia" }
    end

    assert_equal %(no child called "Mia" — the children are: Pau, Teo), refusal.message
  end

  test "no read asks to be confirmed, because none of them changes anything" do
    reads = [Ops::Reads::Attempts, Ops::Reads::Forecast, Ops::Reads::History, Ops::Reads::Progress, Ops::Reads::Status]

    assert_empty reads.select(&:confirmation_required?)
  end

  private

  def today
    Household.with_zone { Date.current }
  end

  def read(&)
    capture_io(&).first
  end

  def prompts_in(output)
    output.lines.select { it.include? "rung " }.map { it.strip.split(/\s{2,}/).last }
  end

  def lapse!(card:, on:, answer: "1", index: 1)
    record_attempt! card:, on:, answer:, index:, verdict: "wrong", seconds: 3.0
  end

  def answered!(card:, on:, answer:, seconds:)
    record_attempt! card:, on:, answer:, index: 1, verdict: "correct", seconds:
  end

  def record_attempt!(card:, on:, answer:, index:, verdict:, seconds:)
    children(:pau).attempts.create! card:, study_date: on, prompt: card.prompt,
      accepted_keys: card.accepted_keys, answer:, verdict:, seconds_to_answer: seconds,
      attempt_index: index, showing_token: "showing-#{card.id}-#{on}-#{index}"
  end

  def day!(on:, **attributes)
    children(:pau).study_days.create! study_date: on, first_opened_at: on.to_time, **attributes
  end

  def due_card!(prompt:, position:, on:)
    card = decks(:addition).cards.create! position:, prompt:, accepted_answers: ["18"]
    children(:pau).card_progresses.find_by!(card:).update! due_on: on
  end

  def child_with_due_cards(name:, due:)
    child = Child.create! name:, color: "pink", created_on: today
    deck = Deck.create! name: "#{name}'s deck"
    child.deck_assignments.create! deck:, position: 1

    due.times do |index|
      card = deck.cards.create! position: index + 1, prompt: "#{name} #{index} + 0", accepted_answers: [index.to_s]
      child.card_progresses.find_by!(card:).update! due_on: today
    end

    child
  end
end
