require "test_helper"

class StudiesControllerTest < ActionDispatch::IntegrationTest
  # 23:30 UTC on the 13th is 08:30 Tokyo on the 14th, which is the date the fixtures call today.
  setup do
    travel_to Time.utc(2026, 9, 13, 23, 30)
    @child = children(:pau)
  end

  test "the root renders the next due card for the paired child, with no start screen" do
    pair_device_as @child

    get "/"

    assert_response :success
    assert_select "[data-screen=study]"
    assert_select ".question", "23 + 19"
    assert_select "a", false
  end

  test "rendering a card writes a new showing token, stamps the time, and snapshots the prompt and accepted keys" do
    pair_device_as @child
    item = queue_items(:pau_sum_23_19)

    get "/"

    item.reload
    assert_not_equal "showing-pau-23-19", item.showing_token
    assert_equal Time.utc(2026, 9, 13, 23, 30), item.shown_at
    assert_equal "23 + 19", item.shown_prompt
    assert_equal ["42"], item.shown_accepted_keys
    assert_select "input[name=showing_token][value=?]", item.showing_token
  end

  test "a card the agent edited is shown in its new form at the next showing, which is what the snapshot records" do
    pair_device_as @child

    get "/"

    queue_items(:pau_sum_23_19).card.update! prompt: "27 + 15", accepted_answers: ["42"]

    get "/"

    assert_select ".question", "27 + 15"
    assert_equal "27 + 15", queue_items(:pau_sum_23_19).reload.shown_prompt
  end

  test "reopening mid-session shows the same card and the same progress (AE10)" do
    pair_device_as @child
    queue_items(:pau_sum_23_19).update! cleared_at: Time.current, cleared_reason: :correct
    wrong = queue_items(:pau_sum_38_27)
    wrong.update! last_wrong_at: Time.current, wrong_count: 1

    get "/"

    assert_select ".question", "38 + 27"
    assert_progress cleared: 1, of: 2
    first_token = wrong.reload.showing_token

    get "/"

    assert_select ".question", "38 + 27"
    assert_progress cleared: 1, of: 2
    assert_not_equal first_token, wrong.reload.showing_token
  end

  test "progress renders as the cards cleared today over those cleared plus the cards still in the queue" do
    pair_device_as @child

    get "/"

    assert_progress cleared: 0, of: 2

    queue_items(:pau_sum_23_19).update! cleared_at: Time.current, cleared_reason: :correct

    get "/"

    assert_progress cleared: 1, of: 2

    study_days(:pau_today).remove_card! cards(:sum_38_27)

    get "/"

    assert_progress cleared: 1, of: 1
    assert_select ".question", false
  end

  test "a day of one card draws one mark rather than a row with nothing beside it" do
    pair_device_as @child
    study_days(:pau_today).remove_card! cards(:sum_38_27)

    get "/"

    assert_progress cleared: 0, of: 1
  end

  test "reopening a day animates nothing, however many cards are already cleared" do
    pair_device_as @child
    queue_items(:pau_sum_23_19).update! cleared_at: Time.current, cleared_reason: :correct

    get "/"

    # The row is replaced wholesale on every render, so a mark carrying the animation class on a
    # plain reopen would play again for a card the child cleared hours ago.
    assert_progress cleared: 1, of: 2
    assert_select "#progress svg.pip-new", count: 0
  end

  test "the screen carries both of the child's colors, the right way round" do
    pair_device_as @child

    get "/"

    # Both methods exist and both are called, so swapping them raises nothing and every other
    # assertion still passes — the children would simply wear each other's dark-mode color.
    style = response.parsed_body.at_css("#screen")["style"]
    assert_includes style, "--child-light: #{@child.color_hex}"
    assert_includes style, "--child-dark: #{@child.color_hex_dark}"
  end

  test "the lost-identity screen carries the hook its neutral ground needs" do
    get "/"

    screen = response.parsed_body.at_css("#screen")
    assert_includes screen["class"].split, "lost"
    # The per-child grounds are color-mix() over --child-light, which this screen has no child
    # to supply. The neutral ground is written as #screen.lost precisely because the element
    # carries the id too, and a bare class would lose to it.
    assert_not_includes screen["style"].to_s, "--child-light"
  end

  test "the root renders the lost-identity screen for an unpaired device" do
    get "/"

    assert_response :success
    assert_select "[data-screen=lost-identity]"
    assert_select "[data-screen=study]", false
    assert_empty body_letters
  end

  test "the root renders the lost-identity screen once the child's device is forgotten" do
    pair_device_as(@child).forget!

    get "/"

    assert_response :success
    assert_select "[data-screen=lost-identity]"
  end

  test "the study screen carries no words at all: numerals and icons only" do
    pair_device_as @child

    get "/"

    assert_empty body_letters
  end

  test "the submit key is an enter arrow carrying no letters anywhere" do
    pair_device_as @child

    get "/"

    submit = response.parsed_body.at_css("button[type=submit]")
    assert_no_match(/\p{L}/, submit.text)
    assert_nil submit["aria-label"]
    assert_nil submit["title"]
    assert_nil submit["value"]
    assert submit.at_css("svg"), "the submit key draws its arrow"
  end

  test "the digit keys are plain buttons so only the submit key submits the form" do
    pair_device_as @child

    get "/"

    assert_select "button[type=submit]", 1
    assert_select "[data-key='7'][type=button]"
    assert_select "[data-key=backspace][type=button]"
  end

  test "the typed answer and the showing token belong to the pad's form from inside the swapped region" do
    pair_device_as @child

    get "/"

    form = response.parsed_body.at_css("form")
    assert_equal "/answers", form["action"]
    assert_nil form.at_css("[name=answer]"), "the typed display belongs to the form by its form attribute"

    card = response.parsed_body.at_css("#card")
    assert_equal form["id"], card.at_css("[name=answer]")["form"]
    assert_equal form["id"], card.at_css("[name=showing_token]")["form"]
  end

  test "the pad's form and its keys sit outside the region a verdict swaps" do
    pair_device_as @child

    get "/"

    card = response.parsed_body.at_css("#card")
    assert_nil card.at_css("form")
    assert_nil card.at_css("[data-key]")
  end

  test "a first open with nothing due and nothing admitted lands on the done screen (AE6)" do
    child = Child.create! name: "Mar", color: "pink", created_on: Date.new(2026, 9, 1)
    pair_device_as child

    get "/"

    assert_response :success
    assert_select "[data-screen=done]"
    assert_select ".question", false
    assert_select "[data-key=submit]", false
    assert_progress cleared: 0, of: 0
    assert_not_nil child.study_days.sole.done_at
  end

  test "reopening after done shows the done screen, and the celebration does not replay (AE2)" do
    pair_device_as @child
    day = finished_day
    decks(:addition).cards.create! position: 9, prompt: "1 + 1", accepted_answers: ["2"]

    get "/"

    assert_select "[data-screen=done][data-controller=done]"
    assert_select ".question", false
    assert_equal Time.utc(2026, 9, 13, 23, 30), day.reload.done_seen_at

    travel 1.hour
    get "/"

    assert_select "[data-screen=done]"
    assert_select "[data-screen=done][data-controller=done]", false
    assert_equal Time.utc(2026, 9, 13, 23, 30), day.reload.done_seen_at
  end

  test "the done screen carries no sentence: the child's name, and the row they filled" do
    pair_device_as @child
    finished_day

    get "/"

    done = response.parsed_body.at_css("[data-screen=done]")
    assert_equal ["Pau"], done.text.scan(/\p{L}+/)

    # The celebration is the progress row rather than a second set of stars inside the card:
    # one mark meaning one cleared card, grown, and not the same shape saying two things on the
    # one screen that is supposed to feel like arriving.
    assert_nil done.at_css("svg"), "the done screen draws no marks of its own"
    assert_progress cleared: 2, of: 2
  end

  private

  def finished_day
    study_days(:pau_today).tap do |day|
      day.queue_items.each { it.clear! :correct }
      day.settle!
    end
  end

  def body_letters
    response.parsed_body.at_css("body").text.scan(/\p{L}+/)
  end
end
