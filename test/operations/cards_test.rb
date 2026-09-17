require "test_helper"

class CardsTest < ActiveSupport::TestCase
  # 23:30 UTC on the 13th is 08:30 Tokyo on the 14th, the date the fixtures call today.
  setup { travel_to Time.utc(2026, 9, 13, 23, 30) }

  test "deleting a card a child has attempted is refused and the message names retire (AE12)" do
    refusal = assert_raises Ops::Base::Refused do
      Ops::Cards::Delete.call deck: "Addition to 100", prompt: "38 + 27"
    end

    assert_includes refusal.message, "retire"
    assert Card.exists?(cards(:sum_38_27).id)
  end

  test "deleting a card nobody has attempted succeeds (AE12)" do
    card = cards(:times_6_7)

    out, = capture_io { Ops::Cards::Delete.call deck: "Times tables", prompt: "6 × 7" }

    assert_not Card.exists?(card.id)
    assert_equal 1, out.lines.size
    assert_includes out, "cards 1 → 0"
  end

  test "adding a card whose accepted answer is not one to six digits is refused (AE12)" do
    ["3.5", "-2", "1234567"].each do |answer|
      refusal = assert_raises Ops::Base::Refused do
        Ops::Cards::Add.call deck: "Addition to 100", cards: {"9 + 9" => answer}, confirm: true
      end

      assert_includes refusal.message, answer
    end

    assert_equal 3, decks(:addition).cards.count
  end

  test "adding a card with no accepted answer is refused" do
    assert_raises Ops::Base::Refused do
      Ops::Cards::Add.call deck: "Addition to 100", cards: {"9 + 9" => []}, confirm: true
    end

    assert_equal 3, decks(:addition).cards.count
  end

  test "a bulk add without the confirmation keyword prints the plan and adds nothing (AE12)" do
    out, = capture_io { Ops::Cards::Add.call deck: "Addition to 100", cards: {"9 + 9" => "18"} }

    assert_equal 1, out.lines.size
    assert_includes out, "plan (nothing changed, pass confirm: true)"
    assert_includes out, "cards 3 → 4"
    assert_equal 3, decks(:addition).cards.count
  end

  test "a duplicate prompt in the same deck is refused, and so is one repeated inside the batch" do
    assert_raises Ops::Base::Refused do
      Ops::Cards::Add.call deck: "Addition to 100", cards: {"23+19" => "42"}, confirm: true
    end

    assert_raises Ops::Base::Refused do
      Ops::Cards::Add.call deck: "Addition to 100", cards: {"9 + 9" => "18", "9+9" => "18"}, confirm: true
    end

    assert_equal 3, decks(:addition).cards.count
  end

  test "the same prompt in another deck is accepted" do
    capture_io { Ops::Cards::Add.call deck: "Times tables", cards: {"23 + 19" => "42"}, confirm: true }

    assert decks(:tables).cards.exists?(prompt_key: "23 + 19")
  end

  test "a spacing-only prompt edit keeps every child's progress (AE11)" do
    pau, teo = card_progresses(:pau_sum_23_19), card_progresses(:teo_sum_23_19)

    out, = capture_io { Ops::Cards::Update.call deck: "Addition to 100", prompt: "23 + 19", to: "23+19" }

    assert_equal "23+19", cards(:sum_23_19).reload.prompt
    assert_equal [4, Date.new(2026, 9, 14)], [pau.reload.rung, pau.due_on]
    assert_equal [1, Date.new(2026, 9, 15)], [teo.reload.rung, teo.due_on]
    assert_includes out, "progress kept"
  end

  test "changing the question resets progress to new and reports the one child reset (AE11)" do
    progress = card_progresses(:pau_times_6_7)
    progress.update! rung: 5, due_on: Date.new(2026, 9, 30), last_answered_on: Date.new(2026, 9, 14)

    out, = capture_io { Ops::Cards::Update.call deck: "Times tables", prompt: "6 × 7", to: "7 × 6" }

    assert_equal ["7 × 6", ["42"]], [cards(:times_6_7).reload.prompt, cards(:times_6_7).accepted_answers]
    assert_equal [0, nil, nil], [progress.reload.rung, progress.due_on, progress.last_answered_on]
    assert_includes out, "1 child reset to new"
  end

  # The item froze the accepted answers when it was rendered, so a card left in an open queue
  # would grade the corrected question against the answer the correction replaced.
  test "a corrected card leaves the queue of the day the child already has open" do
    capture_io { Ops::Cards::Update.call deck: "Addition to 100", prompt: "23 + 19", answers: ["41"] }

    assert_equal "removed", queue_items(:pau_sum_23_19).reload.cleared_reason
    assert_equal 1, study_days(:pau_today).reload.remaining_count
  end

  test "changing only the accepted answers resets progress too" do
    progress = card_progresses(:pau_times_6_7)
    progress.update! rung: 5, due_on: Date.new(2026, 9, 30)

    out, = capture_io { Ops::Cards::Update.call deck: "Times tables", prompt: "6 × 7", answers: ["43"] }

    assert_equal ["43"], cards(:times_6_7).reload.accepted_answers
    assert_nil progress.reload.due_on
    assert_includes out, "1 child reset to new"
  end

  test "an update whose answers the pad cannot type is refused" do
    assert_raises Ops::Base::Refused do
      Ops::Cards::Update.call deck: "Addition to 100", prompt: "23 + 19", answers: ["4.2"]
    end

    assert_equal ["42"], cards(:sum_23_19).reload.accepted_answers
  end

  test "an update with nothing to change is refused" do
    assert_raises Ops::Base::Refused do
      Ops::Cards::Update.call deck: "Addition to 100", prompt: "23 + 19"
    end
  end

  test "retiring a card takes it out of today's queue and keeps every child's progress" do
    out, = capture_io { Ops::Cards::Retire.call deck: "Addition to 100", prompt: "23 + 19" }

    assert cards(:sum_23_19).reload.retired?
    assert_equal "removed", queue_items(:pau_sum_23_19).reload.cleared_reason
    assert_equal [4, Date.new(2026, 9, 14)], [card_progresses(:pau_sum_23_19).reload.rung, card_progresses(:pau_sum_23_19).due_on]
    assert_nil study_days(:pau_today).reload.done_at
    assert_includes out, "out of 1 open queue"
  end

  test "retiring and unretiring a card resumes each child's due date and leaves it new for a child never admitted to it" do
    admitted, unseen = card_progresses(:pau_sum_38_27), card_progresses(:teo_sum_38_27)

    capture_io { Ops::Cards::Retire.call deck: "Addition to 100", prompt: "38 + 27" }

    assert cards(:sum_38_27).reload.retired?

    out, = capture_io { Ops::Cards::Unretire.call deck: "Addition to 100", prompt: "38 + 27" }

    assert_not cards(:sum_38_27).reload.retired?
    assert_equal Date.new(2026, 9, 14), admitted.reload.due_on
    assert_equal Date.new(2026, 9, 13), admitted.parked_on
    assert_nil unseen.reload.due_on
    assert_includes out, "due again for 1 child, new for 1 child"
  end

  test "unretiring is refused while another card holds that prompt in the deck" do
    capture_io { Ops::Cards::Retire.call deck: "Addition to 100", prompt: "7 - 7" }
    capture_io { Ops::Cards::Add.call deck: "Addition to 100", cards: {"7 - 7" => "0"}, confirm: true }

    assert_raises Ops::Base::Refused do
      Ops::Cards::Unretire.call deck: "Addition to 100", prompt: "7 - 7"
    end

    assert cards(:difference_7_7).reload.retired?
  end

  test "a batch added with the due-today option is due today for every assigned child, and joins no open queue" do
    out, = capture_io do
      Ops::Cards::Add.call deck: "Addition to 100", cards: {"9 + 9" => "18"}, due_today: true, confirm: true
    end

    added = decks(:addition).cards.find_by! prompt_key: "9 + 9"

    assert_equal [Date.new(2026, 9, 14)], added.card_progresses.map(&:due_on).uniq
    assert_equal [children(:pau), children(:teo)].sort_by(&:id), added.card_progresses.map(&:child).sort_by(&:id)
    assert_equal 2, study_days(:pau_today).queue_items.count
    assert_includes out, "due today for 2 children"
  end

  test "a batch added at the front moves the deck's cards down" do
    capture_io { Ops::Cards::Add.call deck: "Addition to 100", cards: {"1 + 1" => "2"}, at: "front", confirm: true }

    assert_equal ["1 + 1", "23 + 19", "38 + 27", "7 - 7"], decks(:addition).cards.order(:position).pluck(:prompt)
    assert_equal [1, 2, 3, 4], decks(:addition).cards.order(:position).pluck(:position)
  end

  test "deleting a card that is currently shown to a child leaves that showing gradable and records the attempt" do
    card = cards(:sum_23_19)
    shown = queue_items(:pau_sum_23_19).show!

    capture_io { Ops::Cards::Delete.call deck: "Addition to 100", prompt: "23 + 19" }

    assert_not Card.exists?(card.id)
    assert_equal "removed", shown.reload.cleared_reason

    travel 4.seconds
    attempt = shown.answer! "42"

    assert attempt.persisted?
    assert attempt.correct?
    assert_equal ["23 + 19", nil], [attempt.prompt, attempt.card_id]
  end

  test "an operation names the deck it cannot find" do
    refusal = assert_raises Ops::Base::Refused do
      Ops::Cards::Retire.call deck: "Division", prompt: "23 + 19"
    end

    assert_includes refusal.message, "Division"
  end
end
