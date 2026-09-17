require "application_system_test_case"

class StudyTest < ApplicationSystemTestCase
  IPAD_LANDSCAPE = [1180, 820].freeze
  IPAD_PORTRAIT = [820, 1180].freeze

  # Headless Chrome resolves every env(safe-area-inset-*) to zero, and those insets are the only
  # thing that pads the body. So a test resized to the raw dimensions above hands the app more
  # height than a real iPad in standalone does. These stand in for the home indicator and the
  # status bar: a model of the device, not a measurement of one, and deliberately generous.
  SAFE_AREA_VERTICAL = {landscape: 24, portrait: 48}.freeze

  # Apple's minimum touch target.
  TOUCH_TARGET = 44

  # 23:30 UTC on the 13th is 08:30 Tokyo on the 14th, which is the date the fixtures call today.
  setup do
    travel_to Time.utc(2026, 9, 13, 23, 30)
    open_study_screen children(:pau)
  end

  test "the root opens on the current question with the pad and no way out of it" do
    assert_selector "[data-screen=study]"
    assert_selector ".question", text: "23 + 19"
    assert_selector "[data-key=submit]"
    assert_no_selector "a"
  end

  test "tapping digits appends them to the display and backspace removes the last" do
    tap_key "4"
    tap_key "2"

    assert_typed "42"

    tap_key "backspace"

    assert_typed "4"
  end

  test "the submit key with an empty display does nothing (AE9)" do
    capture_submissions

    tap_key "submit"

    assert_empty submissions

    tap_key "4"
    tap_key "2"
    tap_key "submit"

    assert_equal ["42"], submissions(1).pluck("answer")
  end

  test "the pad accepts at most six digits" do
    (1..7).each { tap_key it.to_s }

    assert_typed "123456"
  end

  test "typing digits on a hardware keyboard and pressing Enter submits the same way" do
    capture_submissions
    token = showing_token

    type_keys "4", "8", :backspace, "2"

    assert_typed "42"

    type_keys :enter

    submission = submissions(1).sole
    assert_equal "42", submission["answer"]
    assert_equal token, submission["showing_token"]
  end

  test "a page rendered on a previous study day reloads the root when it becomes visible again" do
    token = showing_token
    # travel_to moves the server's clock and not the browser's, so this half has to stamp the
    # page with the date the controller will actually compute rather than the fixtures' date.
    stamp_resume_date browser_today

    become_visible
    # The reload this half denies is asynchronous, so the assertion has to give it time to
    # have happened rather than winning the race against it.
    sleep 0.25

    assert_equal token, showing_token

    stamp_resume_date "2026-09-13"
    become_visible

    assert_no_selector "input[name=showing_token][value='#{token}']", visible: :all
    assert_selector ".question", text: "23 + 19"
  end

  test "a correct answer advances by itself after the delay, with no tap" do
    answer "42"

    assert_selector ".verdict .echo", text: "42"
    assert_no_selector ".verdict"
    assert_selector ".question", text: "38 + 27"
    assert_progress cleared: 1, of: 2
    assert_typed ""
  end

  test "digits tapped and a submit made while the verdict overlay is showing record no attempt" do
    answer "42"

    assert_selector ".verdict"
    tap_keys_at_once "6", "5", "submit"

    assert_no_selector ".verdict"
    assert_selector ".question", text: "38 + 27"
    assert_typed ""
    assert_progress cleared: 1, of: 2
    assert_equal 1, attempts_today
  end

  test "a submit whose request fails shows the no-connection screen, keeps the digits, and retries by itself" do
    retry_after 200
    fail_next_fetch

    answer "42"

    assert_selector "[data-screen=no-connection]"
    assert_typed "42"
    assert_equal "no-connection", screen_over(".key-enter")

    assert_selector ".verdict .echo", text: "42"
    assert_no_selector "[data-screen=no-connection]"
    assert_equal 1, attempts_today
  end

  test "a submit answered with a server error keeps the card on screen and never renders the error body" do
    serve_error "Marzipan"

    answer "42"

    assert_selector "[data-screen=no-connection]"
    assert_selector ".question", text: "23 + 19"
    assert_no_text "Marzipan"
    assert_typed "42"
  end

  test "a submit the server refuses reloads the root rather than retrying a request that cannot succeed" do
    retry_after 200
    mark_document
    serve_status 422

    answer "42"

    assert_selector ".question", text: "23 + 19"
    assert_no_selector "[data-screen=no-connection]"
    assert_nil page.evaluate_script("window.documentMarker"), "the root was never reloaded"
    assert_equal 0, attempts_today
  end

  test "a retry that never starts leaves the loop still retrying" do
    retry_after 200
    prevent_second_submit
    fail_next_fetch

    answer "42"

    assert_selector "[data-screen=no-connection]"

    assert_selector ".verdict .echo", text: "42"
    assert_no_selector "[data-screen=no-connection]"
    assert_equal 1, attempts_today
  end

  test "a digit typed while a submit is in flight is ignored, so the answer graded is the answer sent" do
    stall_next_fetch 3000

    answer "42"
    type_keys "7"

    assert_typed "42"

    assert_selector ".verdict .echo", text: "42"
    assert_equal 1, attempts_today
  end

  test "the answer held behind the no-connection screen cannot be retyped, so the retry carries it back" do
    retry_after 3000
    fail_next_fetch

    answer "42"

    assert_selector "[data-screen=no-connection]"
    type_keys :backspace, :backspace, "7"

    assert_typed "42"

    assert_selector ".verdict .echo", text: "42"
    assert_equal 1, attempts_today
  end

  test "a submit that stalls rather than fails shows the waiting screen and clears it when the stream lands" do
    stall_next_fetch 2000

    answer "42"

    assert_selector "[data-screen=no-connection]"
    assert_no_selector ".verdict", wait: 0

    assert_selector ".question", text: "38 + 27"
    assert_no_selector "[data-screen=no-connection]"
  end

  test "a wrong answer shows the child's answer beside the right one, and only the next digit of it is taken (AE8)" do
    cards(:sum_23_19).update! accepted_answers: ["０４２"]
    visit "/"
    count_fetches

    answer "41"

    assert_selector ".correction .struck", text: "41"
    assert_selector ".correction .expected", text: "42"
    assert_no_selector ".verdict"
    assert_selector ".question", text: "38 + 27"

    tap_key "0"

    assert_no_selector ".expected [data-copied]"

    tap_key "4"

    assert_selector ".expected [data-copied]", count: 1

    tap_key "4"

    assert_selector ".expected [data-copied]", count: 1

    tap_key "2"

    assert_no_selector ".correction"
    assert_selector ".question", text: "38 + 27"
    assert_typed ""
    assert_equal 1, fetches
    assert_equal 1, attempts_today
  end

  test "the submit key and backspace do nothing during the copy, and no attempt is recorded" do
    answer "41"

    assert_selector ".correction"
    capture_submissions

    tap_key "submit"
    tap_key "backspace"
    tap_key "4"
    tap_key "submit"

    assert_selector ".correction .expected [data-copied]", count: 1
    assert_empty submissions
    assert_equal 1, attempts_today
    assert_typed ""
  end

  test "answering one card wrong three times parks it and the day moves on (AE5)" do
    answer "42"

    assert_selector ".verdict .echo", text: "42"
    assert_no_selector ".verdict"

    2.times do
      answer "1"

      assert_selector ".correction .struck", text: "1"
      copy "65"

      assert_no_selector ".correction"
      assert_selector ".question", text: "38 + 27"
      assert_progress cleared: 1, of: 2
    end

    answer "1"

    assert_selector ".correction .expected", text: "65"
    copy "65"

    assert_no_selector ".correction"
    assert_no_selector ".question"
    assert_progress cleared: 2, of: 2
    assert_equal "parked", queue_items(:pau_sum_38_27).reload.cleared_reason
    assert_not_nil study_days(:pau_today).reload.done_at
  end

  test "the question and the submit key both stay on screen at iPad landscape dimensions" do
    desktop = page.current_window.size

    [IPAD_LANDSCAPE, IPAD_PORTRAIT].each do |dimensions|
      resize_viewport_to(*dimensions)

      assert_within_viewport ".question"
      assert_within_viewport "[data-key=submit]"
    end
  ensure
    page.current_window.resize_to(*desktop)
  end

  test "every key clears the touch target at both iPad orientations inside the safe area" do
    desktop = page.current_window.size

    # The third size is not an iPad. It is short enough that 12dvh falls under the clamp's floor,
    # which is the only way to measure the floor at all — at both iPad sizes the middle value
    # wins, so the floor is never the resolved height there.
    sizes = {landscape: IPAD_LANDSCAPE, portrait: IPAD_PORTRAIT, squat: [1180, 400 + SAFE_AREA_VERTICAL[:landscape]]}

    sizes.each do |orientation, (width, height)|
      resize_viewport_to width, height - SAFE_AREA_VERTICAL.fetch(orientation, SAFE_AREA_VERTICAL[:landscape])

      heights = page.evaluate_script("[...document.querySelectorAll('.key')].map(k => k.getBoundingClientRect().height)")

      assert_equal 12, heights.size
      assert_operator heights.min, :>=, TOUCH_TARGET,
        "a key is #{heights.min}px tall at #{orientation}, under the #{TOUCH_TARGET}px touch target"

      # At the two iPad sizes the clamp resolves to its middle value; at the squat one it
      # resolves to the floor. Between them the assertion above has seen both ends of the clamp
      # rather than only the comfortable one.
      assert_within_viewport "[data-key=submit]"
    end
  ensure
    page.current_window.resize_to(*desktop)
  end

  test "a long backlog keeps its star row on the screen" do
    desktop = page.current_window.size

    # The cap on new cards keeps an ordinary day near a dozen, but nothing caps the cards that
    # come *due* — a child back from a week away meets every one of them at once. Portrait is
    # the tighter of the two, so the row has to survive it.
    day = crowd_the_day 26

    {landscape: IPAD_LANDSCAPE, portrait: IPAD_PORTRAIT}.each do |orientation, (width, height)|
      resize_viewport_to width, height - SAFE_AREA_VERTICAL.fetch(orientation)

      assert_selector "#progress svg.pip", count: day.queue_items.count
      assert_within_viewport "#progress"
    end
  ensure
    page.current_window.resize_to(*desktop)
  end

  test "the taller keys leave the card enough height for a verdict at landscape" do
    desktop = page.current_window.size
    width, height = IPAD_LANDSCAPE
    resize_viewport_to width, height - SAFE_AREA_VERTICAL.fetch(:landscape)

    # This is the assertion the taller keys are actually on the hook for. The pad row is `auto`
    # and the card row is `minmax(0, 1fr)`, so a pad that grows never pushes itself off screen —
    # it crushes the card instead, silently, and the tick and the echoed answer clip inside it.
    # Raising the key floor to 190px takes the card to 23px here, which this catches.
    card = page.evaluate_script("document.querySelector('.card').getBoundingClientRect().height")

    assert_operator card, :>=, 200, "the card is #{card}px tall at landscape — the verdict will clip"
  ensure
    page.current_window.resize_to(*desktop)
  end

  test "an agent removing the last remaining card ends the day, and the next open celebrates it once (AE16)" do
    answer "42"

    assert_selector ".question", text: "38 + 27"

    study_days(:pau_today).remove_card! cards(:sum_38_27)
    visit "/"

    assert_selector "[data-screen=done].celebrating", text: "Pau"
    assert_progress cleared: 1, of: 1
    assert_no_selector "[data-key=submit]"

    visit "/"

    assert_selector "[data-screen=done]", text: "Pau"
    assert_no_selector ".celebrating"
  end

  test "the last correct answer reveals the done screen when the verdict lifts" do
    study_days(:pau_today).remove_card! cards(:sum_38_27)
    visit "/"

    answer "42"

    assert_selector ".verdict .echo", text: "42"
    assert_selector "[data-screen=done].celebrating", text: "Pau"
    assert_no_selector ".verdict"
    assert_no_selector "[data-key=submit]"
    assert_progress cleared: 1, of: 1
  end

  test "the done screen waits under the correction until the copy's last digit reveals it" do
    study_days(:pau_today).remove_card! cards(:sum_23_19)
    visit "/"

    2.times do
      answer "1"

      assert_selector ".correction .struck", text: "1"
      assert_no_selector "[data-screen=done]"
      copy "65"
    end

    answer "1"

    assert_selector ".correction .expected", text: "65"
    assert_selector "[data-screen=done]"
    assert_no_selector ".celebrating"

    # The done screen is rendered, but the child is still copying digits on the pad. The row it
    # grows into sits outside the card the correction covers, so keying the done layout on the
    # done screen alone would centre and enlarge it here, and drop the pad row out from under
    # the digits being typed.
    assert_within_viewport ".keys"
    # Right-aligned, not centred. A midpoint comparison would pass either way on a one-card day,
    # because a single centred star still sits past the middle.
    gap_to_edge = page.evaluate_script("innerWidth") - progress_box["right"]
    assert_operator gap_to_edge, :<, 40,
      "the star row is #{gap_to_edge.round}px from the right edge — it has already centred while the correction is up"

    copy "65"

    assert_no_selector ".correction"
    assert_selector "[data-screen=done].celebrating", text: "Pau"
    assert_progress cleared: 1, of: 1
  end

  # Teo, not Pau: his day has not been opened yet, so this is the only child whose first open
  # is the one that assembles the queue. Two new cards are all he has left to be admitted.
  test "a whole day, from the first open that assembles the queue to the done screen (F2)" do
    open_study_screen children(:teo)
    day = children(:teo).study_days.find_by! study_date: Date.new(2026, 9, 14)

    assert_equal [0, 2], [day.due_count_at_open, day.new_count_at_open]
    assert_progress cleared: 0, of: 2
    assert_selector ".question", text: "38 + 27"

    answer "56"

    assert_selector ".correction .struck", text: "56"
    assert_selector ".correction .expected", text: "65"
    copy "65"

    assert_no_selector ".correction"
    assert_selector ".question", text: "7 - 7"
    assert_progress cleared: 0, of: 2

    answer "0"

    assert_selector ".verdict .echo", text: "0"
    assert_no_selector ".verdict"
    assert_selector ".question", text: "38 + 27"
    assert_progress cleared: 1, of: 2

    answer "65"

    assert_selector ".verdict .echo", text: "65"
    assert_selector "[data-screen=done].celebrating", text: "Teo"
    assert_progress cleared: 2, of: 2

    visit "/"

    assert_selector "[data-screen=done]", text: "Teo"
    assert_no_selector ".celebrating"
    assert_no_selector "[data-key=submit]"

    lapsed = CardProgress.find_by! card: cards(:sum_38_27), child: children(:teo)
    assert_not_nil day.reload.done_at
    assert_equal 3, children(:teo).attempts.where(study_date: day.study_date).count
    assert_equal [0, Date.new(2026, 9, 15)], [lapsed.rung, lapsed.due_on]
  end

  private

  # Puts `count` cards in front of the child today by making that many of their assigned cards
  # due, then opening the day so the queue is assembled from them.
  def crowd_the_day(count)
    child = children(:pau)
    deck = child.decks.first
    now = Time.current

    Card.insert_all((child.card_progresses.count...count).map { |i|
      {deck_id: deck.id, position: 500 + i, prompt: "#{i} + 1", prompt_key: "#{i}+1",
       accepted_answers: [(i + 1).to_s].to_json, accepted_keys: [(i + 1).to_s].to_json,
       content_digest: "crowd#{i}", created_at: now, updated_at: now}
    })
    CardProgress.insert_all(deck.cards.where.missing(:card_progresses).map { |card|
      {child_id: child.id, card_id: card.id, rung: 1, due_on: Date.current, created_at: now, updated_at: now}
    })
    child.card_progresses.update_all due_on: Date.current, rung: 1

    child.study_days.where(study_date: Date.current).destroy_all
    StudyDay.open_for!(child).tap { open_study_screen child }
  end

  def open_study_screen(child)
    visit "/p/#{child.pairing_links.create!.plain_token}"
    visit "/"
  end

  def tap_key(key)
    find("[data-key='#{key}']").click
  end

  def answer(digits)
    copy digits
    tap_key "submit"
  end

  # The copy is a tap per digit and no submit: its last digit is what continues.
  def copy(digits)
    digits.each_char { tap_key it }
  end

  # Turbo's request for the answer is the only one the wrong path makes.
  def count_fetches
    page.execute_script <<~JS
      const original = window.fetch
      window.fetchCount = 0
      window.fetch = (input, init) => { window.fetchCount += 1; return original(input, init) }
    JS
  end

  def fetches
    page.evaluate_script "window.fetchCount"
  end

  # One round trip, so the taps land inside the verdict overlay's own 800 milliseconds
  # rather than racing it one WebDriver command at a time.
  def tap_keys_at_once(*keys)
    page.execute_script keys.map { %(document.querySelector("[data-key='#{it}']").click()) }.join("\n")
  end

  def retry_after(milliseconds)
    page.execute_script "document.body.dataset.connectionRetryValue = '#{milliseconds}'"
  end

  def fail_next_fetch
    patch_fetch <<~JS
      (input, init) => {
        window.fetch = original
        return Promise.reject(new TypeError("Failed to fetch"))
      }
    JS
  end

  def stall_next_fetch(milliseconds)
    patch_fetch <<~JS
      (input, init) => {
        window.fetch = original
        return new Promise((resolve) => setTimeout(() => resolve(original(input, init)), #{milliseconds}))
      }
    JS
  end

  def serve_status(status)
    patch_fetch %(() => Promise.resolve(new Response("", { status: #{status} })))
  end

  # Nothing carries this across a reload, which is what the escalation to the root has to do.
  def mark_document
    page.execute_script "window.documentMarker = true"
  end

  # The pad refuses a submit it cannot send, and Turbo starts nothing for a prevented one, so
  # the retry it answers produces no submit-end to schedule the next attempt from.
  def prevent_second_submit
    page.execute_script <<~JS
      let submits = 0
      document.querySelector("#answer").addEventListener("submit", (event) => {
        if (++submits === 2) event.preventDefault()
      })
    JS
  end

  def serve_error(marker)
    patch_fetch <<~JS
      () => Promise.resolve(new Response("<html><body>#{marker}</body></html>", {
        status: 500,
        headers: { "Content-Type": "text/html" }
      }))
    JS
  end

  def patch_fetch(handler)
    page.execute_script "const original = window.fetch; window.fetch = #{handler}"
  end

  # What a child's finger would reach at that key: the no-connection overlay swallows every
  # pointer event, so there is nothing under it to tap.
  def screen_over(selector)
    page.evaluate_script(<<~JS)
      ((rect) => document
        .elementFromPoint(rect.left + rect.width / 2, rect.top + rect.height / 2)
        .closest("[data-screen]")?.dataset?.screen
      )(document.querySelector("#{selector}").getBoundingClientRect())
    JS
  end

  def type_keys(*keys)
    find("body").send_keys(*keys)
  end

  def attempts_today
    children(:pau).attempts.where(study_date: Date.new(2026, 9, 14)).count
  end

  def assert_typed(digits)
    assert_field "answer", with: digits
  end

  def showing_token
    find("input[name=showing_token]", visible: :all).value
  end

  def browser_today
    page.evaluate_script "new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Tokyo' }).format(new Date())"
  end

  def stamp_resume_date(date)
    page.execute_script "document.querySelector('[data-controller~=resume]').dataset.resumeDateValue = '#{date}'"
  end

  def become_visible
    page.execute_script "document.dispatchEvent(new Event('visibilitychange'))"
  end

  # There is no JavaScript test runner, so a submit is observed where Turbo makes it: the
  # patched fetch answers with an empty stream, which renders nothing and changes no state.
  def capture_submissions
    page.execute_script(<<~JS)
      window.submissions = []
      window.fetch = (input, init) => {
        window.submissions.push(Object.fromEntries(init.body))
        return Promise.resolve(new Response("", {
          headers: { "Content-Type": "text/vnd.turbo-stream.html" }
        }))
      }
    JS
  end

  def submissions(expected = 0)
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep 0.05 until page.evaluate_script("window.submissions.length") >= expected
    end
    page.evaluate_script("window.submissions")
  rescue Timeout::Error
    flunk "expected #{expected} submission(s), got #{page.evaluate_script("window.submissions").inspect}"
  end

  # The window is larger than the page inside it, so the iPad's dimensions are given to the
  # viewport rather than to the window that frames it.
  def resize_viewport_to(width, height)
    frame = page.evaluate_script("[outerWidth - innerWidth, outerHeight - innerHeight]")
    page.current_window.resize_to width + frame.first, height + frame.last
  end

  def progress_box
    page.evaluate_script("(() => { const r = document.querySelector('#progress').getBoundingClientRect(); return {right: r.right, left: r.left} })()")
  end

  def assert_within_viewport(selector)
    assert within_viewport?(selector),
      "#{selector} is outside the #{page.evaluate_script("[innerWidth, innerHeight]").inspect} viewport"
  end

  def within_viewport?(selector)
    page.evaluate_script(<<~JS)
      ((rect) => rect.width > 0 && rect.height > 0 &&
        rect.top >= 0 && rect.left >= 0 &&
        rect.bottom <= window.innerHeight && rect.right <= window.innerWidth
      )(document.querySelector("#{selector}").getBoundingClientRect())
    JS
  end
end
