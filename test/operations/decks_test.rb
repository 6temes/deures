require "test_helper"

class DecksTest < ActiveSupport::TestCase
  # 23:30 UTC on the 13th is 08:30 Tokyo on the 14th, the date the fixtures call today.
  setup { travel_to Time.utc(2026, 9, 13, 23, 30) }

  test "creating a deck" do
    out, = capture_io { Ops::Decks::Create.call name: "Subtraction to 100" }

    assert Deck.exists?(name: "Subtraction to 100")
    assert_equal 1, out.lines.size
    assert_includes out, "decks 2 → 3"
  end

  test "assigning a deck gives the child a progress row per card, with no due date" do
    out, = capture_io { Ops::Decks::Assign.call child: "Teo", deck: "Times tables", confirm: true }

    progress = children(:teo).card_progresses.find_by! card: cards(:times_6_7)

    assert_nil progress.due_on
    assert_equal 2, children(:teo).deck_assignments.assigned.find_by!(deck: decks(:tables)).position
    assert_includes out, "decks 1 → 2"
  end

  test "assigning without the confirmation keyword prints the plan and changes nothing" do
    out, = capture_io { Ops::Decks::Assign.call child: "Teo", deck: "Times tables" }

    assert_equal 1, out.lines.size
    assert_includes out, "plan (nothing changed, pass confirm: true)"
    assert_equal 1, children(:teo).deck_assignments.assigned.count
    assert_empty children(:teo).card_progresses.where(card: cards(:times_6_7))
  end

  test "assigning a deck the child already studies is refused" do
    refusal = assert_raises Ops::Base::Refused do
      Ops::Decks::Assign.call child: "Pau", deck: "Times tables", confirm: true
    end

    assert_includes refusal.message, "Times tables"
  end

  test "unassigning takes the deck's cards out of the child's open queue and settles the day" do
    day = study_days(:pau_today)

    out, = capture_io { Ops::Decks::Unassign.call child: "Pau", deck: "Addition to 100", confirm: true }

    assert_equal %w[removed removed], day.queue_items.order(:sort_key).pluck(:cleared_reason)
    assert_equal 0, day.remaining_count
    assert_equal Time.utc(2026, 9, 13, 23, 30), day.reload.done_at
    assert_includes out, "2 out of today's queue"
  end

  test "unassigning then re-assigning a deck resumes from the kept due dates" do
    progress = card_progresses(:pau_sum_23_19)

    capture_io { Ops::Decks::Unassign.call child: "Pau", deck: "Addition to 100", confirm: true }

    assert_equal [4, Date.new(2026, 9, 14)], [progress.reload.rung, progress.due_on]
    assert_equal 1, Attempt.count

    assert_no_difference -> { CardProgress.count } do
      capture_io { Ops::Decks::Assign.call child: "Pau", deck: "Addition to 100", confirm: true }
    end

    assert_equal [4, Date.new(2026, 9, 14)], [progress.reload.rung, progress.due_on]
    assert_equal 1, children(:pau).deck_assignments.assigned.find_by!(deck: decks(:addition)).position
    assert_equal 0, study_days(:pau_today).remaining_count
  end

  test "unassigning a deck the child does not study is refused" do
    refusal = assert_raises Ops::Base::Refused do
      Ops::Decks::Unassign.call child: "Teo", deck: "Times tables", confirm: true
    end

    assert_includes refusal.message, "Times tables"
  end

  test "an operation names the child it cannot find" do
    refusal = assert_raises Ops::Base::Refused do
      Ops::Decks::Assign.call child: "Mar", deck: "Times tables", confirm: true
    end

    assert_includes refusal.message, "Mar"
  end
end
