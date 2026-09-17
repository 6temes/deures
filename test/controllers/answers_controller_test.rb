require "test_helper"

class AnswersControllerTest < ActionDispatch::IntegrationTest
  # 23:30 UTC on the 13th is 08:30 Tokyo on the 14th, which is the date the fixtures call today.
  setup do
    travel_to Time.utc(2026, 9, 13, 23, 30)
    @child = children(:pau)
    @day = study_days(:pau_today)
    @device = pair_device_as @child
  end

  test "the same showing token submitted twice records one attempt and returns the same verdict (AE9)" do
    token = show queue_items(:pau_sum_23_19)

    assert_difference -> { Attempt.count }, 1 do
      2.times { submit answer: "42", showing_token: token }
    end

    assert_response :success
    assert_select ".verdict .echo", "42"
    assert_equal "correct", Attempt.find_by!(showing_token: token).verdict
  end

  test "a correct answer records one attempt, clears the card, and streams the next card and the progress" do
    item = queue_items(:pau_sum_23_19)
    token = show item

    assert_difference -> { Attempt.count }, 1 do
      submit answer: "42", showing_token: token
    end

    assert_response :success
    assert_equal "correct", item.reload.cleared_reason
    assert_turbo_stream action: "update", target: "card" do
      assert_select ".verdict .echo", "42"
      assert_select ".question", "38 + 27"
    end
    assert_progress cleared: 1, of: 2, within: "turbo-stream[target=progress] template"
  end

  test "a wrong first answer then a correct second leaves the card due tomorrow at the bottom of the ladder (AE3)" do
    item = queue_items(:pau_sum_23_19)
    progress = card_progresses(:pau_sum_23_19)
    assert_equal 4, progress.rung

    submit answer: "41", showing_token: show(item)

    assert_equal 0, progress.reload.rung
    assert_equal Date.new(2026, 9, 15), progress.due_on

    submit answer: "42", showing_token: show(item.reload)

    assert_equal 0, progress.reload.rung, "a later answer the same day moves nothing"
    assert_equal Date.new(2026, 9, 15), progress.due_on

    travel_to Time.utc(2026, 9, 14, 23, 30)
    tomorrow = StudyDay.open_for! @child
    submit answer: "42", showing_token: show(tomorrow.queue_items.find_by!(card: item.card))

    assert_equal 1, progress.reload.rung
    assert_equal Date.new(2026, 9, 16), progress.due_on
  end

  test "an answer for a card the agent retired a moment ago is graded against the snapshot and the card stays out of the queue" do
    item = queue_items(:pau_sum_23_19)
    token = show item
    item.card.update! retired_at: Time.current
    @day.remove_card! item.card

    assert_difference -> { Attempt.count }, 1 do
      submit answer: "42", showing_token: token
    end

    attempt = Attempt.find_by! showing_token: token
    assert_equal "correct", attempt.verdict
    assert_equal "23 + 19", attempt.prompt
    assert_equal "removed", item.reload.cleared_reason
    assert_select ".question", "38 + 27"
  end

  test "an answer for a card the agent just reset is graded against the snapshot and climbs from the bottom of the ladder" do
    item = queue_items(:pau_sum_23_19)
    token = show item
    item.card.update! prompt: "27 + 15", accepted_answers: ["43"]
    card_progresses(:pau_sum_23_19).update! rung: 0, due_on: nil

    submit answer: "42", showing_token: token

    attempt = Attempt.find_by! showing_token: token
    assert_equal "correct", attempt.verdict
    assert_equal ["42"], attempt.accepted_keys
    assert_equal 1, card_progresses(:pau_sum_23_19).reload.rung
    assert_equal Date.new(2026, 9, 15), card_progresses(:pau_sum_23_19).due_on
  end

  test "the attempt records the raw typed string, its key, the verdict, the seconds, and the attempt index for that card that day" do
    item = queue_items(:pau_sum_23_19)
    token = show item
    travel 3.seconds

    submit answer: "０４２", showing_token: token

    attempt = Attempt.find_by! showing_token: token
    assert_equal @child, attempt.child
    assert_equal item.card, attempt.card
    assert_equal Date.new(2026, 9, 14), attempt.study_date
    assert_equal "23 + 19", attempt.prompt
    assert_equal ["42"], attempt.accepted_keys
    assert_equal "０４２", attempt.answer
    assert_equal "42", attempt.answer_key
    assert_equal "correct", attempt.verdict
    assert_in_delta 3.0, attempt.seconds_to_answer, 0.01
    assert_equal 1, attempt.attempt_index

    second = show item.reload
    submit answer: "42", showing_token: second

    assert_equal 2, Attempt.find_by!(showing_token: second).attempt_index
  end

  test "time to answer is measured from the most recent showing, so a reopen restarts it" do
    item = queue_items(:pau_sum_23_19)
    show item
    travel 40.seconds

    get "/"
    travel 2.seconds
    submit answer: "42", showing_token: item.reload.showing_token

    assert_in_delta 2.0, Attempt.find_by!(showing_token: item.showing_token).seconds_to_answer, 0.01
  end

  test "a request that resolves to no child renders the lost-identity screen rather than the no-connection screen" do
    token = show queue_items(:pau_sum_23_19)
    @device.pairing_link.revoke!

    assert_no_difference -> { Attempt.count } do
      submit answer: "42", showing_token: token
    end

    assert_response :success
    assert_turbo_stream action: "replace", target: "screen" do
      assert_select "[data-screen=lost-identity]"
    end
  end

  test "a submit whose showing token belongs to a previous study day answers 2xx and re-renders the current state" do
    stale = show queue_items(:pau_sum_23_19)
    travel_to Time.utc(2026, 9, 14, 23, 30)

    assert_no_difference -> { Attempt.count } do
      submit answer: "42", showing_token: stale
    end

    assert_response :success
    assert_turbo_stream action: "update", target: "card" do
      assert_select ".verdict", false
      assert_select ".question", "23 + 19"
    end
  end

  test "a submit whose answer is longer than the pad can produce records no attempt" do
    token = show queue_items(:pau_sum_23_19)

    assert_no_difference -> { Attempt.count } do
      submit answer: "0000042", showing_token: token
    end

    assert_response :success
    assert_select ".verdict", false
    assert_select ".question", "23 + 19"
  end

  test "a submit whose answer is nothing but a space records no attempt" do
    token = show queue_items(:pau_sum_23_19)

    assert_no_difference -> { Attempt.count } do
      submit answer: " ", showing_token: token
    end

    assert_response :success
    assert_select ".verdict", false
    assert_select ".question", "23 + 19"
  end

  test "a wrong answer renders the correction over the next card, with no verdict and no timer" do
    item = queue_items(:pau_sum_23_19)

    submit answer: "41", showing_token: show(item)

    assert_response :success
    assert_turbo_stream action: "update", target: "card" do
      assert_select ".correction .struck", "41"
      assert_select ".correction .expected", "42"
      assert_select ".question", "38 + 27"
    end
    assert_select "[data-pad-target=verdict]", false
    assert_select ".correction[data-controller]", false
  end

  test "a correct answer animates the mark it just earned, and only that one" do
    # Clear the first card so the earned mark is the *second*, not the first: asserting on a
    # one-cleared day would pass against `:first-of-type` whether the index was right or not.
    queue_items(:pau_sum_23_19).update! cleared_at: Time.current, cleared_reason: :correct

    submit answer: "65", showing_token: show(queue_items(:pau_sum_38_27).reload)

    assert_progress cleared: 2, of: 2, within: "turbo-stream[target=progress] template"
    assert_select "turbo-stream[target=progress] template svg.pip-new", count: 1
    assert_select "turbo-stream[target=progress] template svg.pip:nth-of-type(2).pip-new"
  end

  test "a wrong answer moves the card to the back of the queue without changing the progress (AE10)" do
    item = queue_items(:pau_sum_23_19)

    submit answer: "41", showing_token: show(item)

    assert_progress cleared: 0, of: 2, within: "turbo-stream[target=progress] template"
    assert_select ".question", "38 + 27"
    # A wrong answer clears nothing, so nothing is newest and nothing animates. The row is an
    # innerHTML swap, so a class computed from the index alone would ride a fresh element and
    # replay the last earned star at the one moment the screen is saying they got it wrong.
    assert_select "turbo-stream[target=progress] template svg.pip-new", count: 0

    get "/"

    assert_select ".question", "38 + 27"
    assert_progress cleared: 0, of: 2

    submit answer: "65", showing_token: show(queue_items(:pau_sum_38_27).reload)

    assert_select ".question", "23 + 19"
  end

  test "a third wrong answer today parks the card, clears it, and advances progress (AE5)" do
    item = queue_items(:pau_sum_23_19)

    2.times { submit answer: "41", showing_token: show(item.reload) }

    assert_nil item.reload.cleared_at
    assert_equal 2, item.wrong_count
    assert_progress cleared: 0, of: 2, within: "turbo-stream[target=progress] template"

    submit answer: "41", showing_token: show(item.reload)

    assert_equal "parked", item.reload.cleared_reason
    assert_select ".correction .expected", "42"
    assert_progress cleared: 1, of: 2, within: "turbo-stream[target=progress] template"
  end

  test "a parked card is due tomorrow and is back in the next day's queue" do
    item = queue_items(:pau_sum_23_19)
    3.times { submit answer: "41", showing_token: show(item.reload) }

    assert_equal "parked", item.reload.cleared_reason

    progress = card_progresses(:pau_sum_23_19).reload
    assert_equal 0, progress.rung
    assert_equal Date.new(2026, 9, 15), progress.due_on

    travel_to Time.utc(2026, 9, 14, 23, 30)

    assert_includes StudyDay.open_for!(@child).queue_items.map(&:card), item.card
  end

  test "a parked card stays flagged until it is next answered correctly" do
    item = queue_items(:pau_sum_23_19)
    progress = card_progresses(:pau_sum_23_19)
    3.times { submit answer: "41", showing_token: show(item.reload) }

    assert_equal Date.new(2026, 9, 14), progress.reload.parked_on

    travel_to Time.utc(2026, 9, 14, 23, 30)
    tomorrow = StudyDay.open_for!(@child).queue_items.find_by! card: item.card
    submit answer: "41", showing_token: show(tomorrow)

    assert_equal Date.new(2026, 9, 14), progress.reload.parked_on

    submit answer: "42", showing_token: show(tomorrow.reload)

    assert_nil progress.reload.parked_on
  end

  test "the correction shows the first accepted answer in its normalized form (AE8)" do
    item = queue_items(:pau_sum_23_19)
    item.card.update! accepted_answers: ["０６５"]

    submit answer: "41", showing_token: show(item)

    assert_select ".correction .expected", "65"
    assert_equal %w[6 5], css_select(".correction .expected span").map(&:text)
  end

  test "parking the last card in the queue ends the day rather than leaving it unfinishable (AE5)" do
    submit answer: "65", showing_token: show(queue_items(:pau_sum_38_27))

    item = queue_items(:pau_sum_23_19)
    3.times { submit answer: "41", showing_token: show(item.reload) }

    assert_equal "parked", item.reload.cleared_reason
    assert_empty @day.reload.queue_items.uncleared
    assert_not_nil @day.done_at
    assert_select ".correction .expected", "42"
    assert_select ".question", false
    assert_progress cleared: 2, of: 2, within: "turbo-stream[target=progress] template"
  end

  test "clearing the last card streams the done screen under the verdict, celebrated once" do
    submit answer: "65", showing_token: show(queue_items(:pau_sum_38_27))
    submit answer: "42", showing_token: show(queue_items(:pau_sum_23_19))

    assert_turbo_stream action: "update", target: "card" do
      assert_select ".verdict .echo", "42"
      assert_select "[data-screen=done][data-controller=done]"
      assert_select ".question", false
    end
    assert_progress cleared: 2, of: 2, within: "turbo-stream[target=progress] template"
    assert_equal Time.utc(2026, 9, 13, 23, 30), @day.reload.done_at
    assert_equal Time.utc(2026, 9, 13, 23, 30), @day.done_seen_at
  end

  test "parking the last card streams the done screen under the correction" do
    submit answer: "65", showing_token: show(queue_items(:pau_sum_38_27))
    item = queue_items(:pau_sum_23_19)

    3.times { submit answer: "41", showing_token: show(item.reload) }

    assert_turbo_stream action: "update", target: "card" do
      assert_select ".correction .expected", "42"
      assert_select "[data-screen=done][data-controller=done]"
      assert_select ".verdict", false
    end
  end

  private

  def show(item)
    item.show!.showing_token
  end

  def submit(answer:, showing_token:)
    post answers_path, params: {answer:, showing_token:}, as: :turbo_stream
  end
end
