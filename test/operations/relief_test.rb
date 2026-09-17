require "test_helper"

class ReliefTest < ActiveSupport::TestCase
  # 23:30 UTC on the 13th is 08:30 Tokyo on the 14th, the date the fixtures call today.
  setup { travel_to Time.utc(2026, 9, 13, 23, 30) }

  test "spreading fifty-eight cards due over five days leaves eleven or twelve a day from today, and later cards stay put (AE13)" do
    child = child_with_backlog name: "Bac", due: 58, later: 3

    capture_io { Ops::Relief::Spread.call child: "Bac", days: 5, confirm: true }
    counts = child.card_progresses.group(:due_on).count

    assert_equal [12, 12, 12, 11, 11], (0..4).map { counts[today + it] }
    assert_equal 3, counts[today + 10]
  end

  test "spreading prints the count it produced for each day" do
    child_with_backlog name: "Cou", due: 7

    out, = capture_io { Ops::Relief::Spread.call child: "Cou", days: 3, confirm: true }

    assert_equal 1, out.lines.size
    assert_includes out, "#{today} 3"
    assert_includes out, "#{today + 1} 2"
    assert_includes out, "#{today + 2} 2"
  end

  test "spreading a backlog without the confirmation keyword prints the plan and changes nothing" do
    child = child_with_backlog name: "Pla", due: 4

    out, = capture_io { Ops::Relief::Spread.call child: "Pla", days: 2 }

    assert_includes out, "plan (nothing changed, pass confirm: true)"
    assert_equal 4, child.card_progresses.where(due_on: ..today).count
  end

  test "a card spread off today leaves the queue of the day the child already has open" do
    capture_io { Ops::Relief::Spread.call child: "Pau", days: 2, confirm: true }

    assert_equal today, card_progresses(:pau_sum_23_19).reload.due_on
    assert_equal today + 1, card_progresses(:pau_sum_38_27).reload.due_on
    assert_equal "removed", queue_items(:pau_sum_38_27).reload.cleared_reason
    assert_nil queue_items(:pau_sum_23_19).reload.cleared_at
    assert_equal 1, study_days(:pau_today).reload.remaining_count
  end

  test "spreading over no days at all is refused" do
    refusal = assert_raises Ops::Base::Refused do
      capture_io { Ops::Relief::Spread.call child: "Pau", days: 0, confirm: true }
    end

    assert_includes refusal.message, "0"
    assert_equal today, card_progresses(:pau_sum_23_19).reload.due_on
  end

  test "excusing a past date records the reason and changes no due dates" do
    due_dates = children(:pau).card_progresses.order(:card_id).pluck :due_on

    out, = capture_io { Ops::Relief::Excuse.call child: "Pau", date: "2026-09-12", reason: "holiday" }
    day = children(:pau).study_days.find_by! study_date: Date.new(2026, 9, 12)

    assert_equal "holiday", day.excuse_reason
    assert_not_nil day.excused_at
    assert_nil day.first_opened_at
    assert_equal due_dates, children(:pau).card_progresses.order(:card_id).pluck(:due_on)
    assert_equal 2, study_days(:pau_today).reload.remaining_count
    assert_includes out, "holiday"
  end

  test "excusing a future date is refused" do
    refusal = assert_raises Ops::Base::Refused do
      capture_io { Ops::Relief::Excuse.call child: "Pau", date: "2026-09-15", reason: "trip" }
    end

    assert_includes refusal.message, "2026-09-15"
    assert_empty children(:pau).study_days.where(study_date: Date.new(2026, 9, 15))
  end

  test "a day excused before the child opens it still assembles their queue at their first open" do
    capture_io { Ops::Relief::Excuse.call child: "Teo", reason: "sick" }

    day = StudyDay.open_for! children(:teo)

    assert_equal today, day.study_date
    assert_equal "sick", day.excuse_reason
    assert_not_nil day.first_opened_at
    assert_equal 0, day.due_count_at_open
    assert_equal 2, day.new_count_at_open
    assert_equal 2, day.queue_items.count
  end

  test "an operation run while the process clock is still on yesterday's UTC date uses the household's date" do
    assert_equal Date.new(2026, 9, 13), Time.now.utc.to_date

    Time.use_zone("UTC") { capture_io { Ops::Relief::Excuse.call child: "Teo", reason: "sick" } }

    assert_equal [Date.new(2026, 9, 14)], children(:teo).study_days.where.not(excused_at: nil).pluck(:study_date)
  end

  test "resetting a child's progress on a card makes it new, so only intake brings it back" do
    out, = capture_io { Ops::Relief::Reset.call child: "Pau", deck: "Addition to 100", prompt: "38 + 27" }
    progress = card_progresses(:pau_sum_38_27).reload

    assert_equal 0, progress.rung
    assert_nil progress.due_on
    assert_nil progress.last_answered_on
    assert_nil progress.parked_on
    assert_includes out, "→ new"
  end

  test "a card reset to new leaves the queue of the day the child already has open" do
    capture_io { Ops::Relief::Reset.call child: "Pau", deck: "Addition to 100", prompt: "38 + 27" }

    assert_equal "removed", queue_items(:pau_sum_38_27).reload.cleared_reason
    assert_nil queue_items(:pau_sum_23_19).reload.cleared_at
    assert_equal 1, study_days(:pau_today).reload.remaining_count
  end

  test "resetting a card the child is not assigned is refused" do
    refusal = assert_raises Ops::Base::Refused do
      capture_io { Ops::Relief::Reset.call child: "Teo", deck: "Times tables", prompt: "6 × 7" }
    end

    assert_includes refusal.message, "Times tables"
  end

  private

  def today
    Household.with_zone { Date.current }
  end

  def child_with_backlog(name:, due:, later: 0)
    child = Child.create! name:, color: "pink", created_on: today
    deck = Deck.create! name: "#{name}'s deck"
    child.deck_assignments.create! deck:, position: 1

    (due + later).times do |index|
      card = deck.cards.create! position: index + 1, prompt: "#{name} #{index} + 0", accepted_answers: [index.to_s]
      child.card_progresses.find_by!(card:).update! due_on: (index < due) ? today - index % 3 : today + 10
    end

    child
  end
end
