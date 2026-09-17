require "test_helper"

# == Schema Information
#
# Table name: study_days
#
#  id                :integer          not null, primary key
#  done_at           :datetime
#  done_seen_at      :datetime
#  due_count_at_open :integer
#  excuse_reason     :string
#  excused_at        :datetime
#  first_opened_at   :datetime
#  new_count_at_open :integer
#  study_date        :date             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  child_id          :integer          not null
#
# Indexes
#
#  index_study_days_on_child_id_and_study_date  (child_id,study_date) UNIQUE
#
# Foreign Keys
#
#  child_id  (child_id => children.id)
#
class StudyDayTest < ActiveSupport::TestCase
  # 23:30 UTC on the 13th is 08:30 Tokyo on the 14th, which is the date the fixtures
  # call today and the disagreement AE7 turns on.
  setup { travel_to Time.utc(2026, 9, 13, 23, 30) }

  test "a study day cannot be created twice for one child and date" do
    duplicate = children(:pau).study_days.new study_date: study_days(:pau_today).study_date

    assert_not duplicate.valid?
    assert duplicate.errors[:child_id].any?
  end

  test "the same date is a separate study day for each child" do
    assert children(:teo).study_days.create!(study_date: study_days(:pau_today).study_date).persisted?
  end

  test "six cards due and a cap of three admits three, so the queue holds nine (AE1)" do
    child = child_with_cards name: "Sis", due: 6, unseen: 5, cap: 3

    day = StudyDay.open_for! child

    assert_equal 9, day.queue_items.count
    assert_equal 6, day.due_count_at_open
    assert_equal 3, day.new_count_at_open
  end

  test "twelve cards due admits no new cards (AE1)" do
    child = child_with_cards name: "Doc", due: 12, unseen: 5

    day = StudyDay.open_for! child

    assert_equal 12, day.queue_items.count
    assert_equal 12, day.due_count_at_open
    assert_equal 0, day.new_count_at_open
  end

  test "seven due with a cap of five admits three, so the queue holds the threshold (AE1)" do
    child = child_with_cards name: "Bru", due: 7, unseen: 5, cap: 5

    day = StudyDay.open_for! child

    assert_equal child.light_day_threshold, day.queue_items.count
    assert_equal 7, day.due_count_at_open
    assert_equal 3, day.new_count_at_open
  end

  test "an admitted card stays due until it is answered (AE1)" do
    child = child_with_cards name: "Hap", due: 0, unseen: 2, cap: 1

    StudyDay.open_for! child

    assert_equal [today], child.card_progresses.where.not(due_on: nil).pluck(:due_on)
  end

  test "a day opened at 08:30 Tokyo on a UTC clock is recorded for the Tokyo date (AE7)" do
    assert_equal Date.new(2026, 9, 13), Time.now.utc.to_date

    day = Time.use_zone("UTC") { StudyDay.open_for! children(:teo) }

    assert_equal Date.new(2026, 9, 14), day.study_date
  end

  test "opening the day twice creates one study day and runs intake once" do
    child = child_with_cards name: "Sle", due: 2, unseen: 4

    first = StudyDay.open_for! child
    travel 5.minutes
    second = StudyDay.open_for! child

    assert_equal first.id, second.id
    assert_equal 1, child.study_days.count
    assert_equal 6, second.queue_items.count
    assert_equal 2, second.due_count_at_open
    assert_equal 4, second.new_count_at_open
    assert_equal Time.utc(2026, 9, 13, 23, 30), second.first_opened_at
  end

  test "a card added after first open waits for tomorrow's first open (AE2)" do
    child = child_with_cards name: "Gru", due: 2, cap: 3
    day = StudyDay.open_for! child

    added = child.decks.sole.cards.create! position: 99, prompt: "Gru late + 0", accepted_answers: ["1"]

    assert_equal 2, day.queue_items.count
    assert_not_includes day.queue_items.map(&:card_id), added.id

    travel_to Time.utc(2026, 9, 14, 23, 30)
    tomorrow = StudyDay.open_for! child

    assert_equal Date.new(2026, 9, 15), tomorrow.study_date
    assert_includes tomorrow.queue_items.map(&:card_id), added.id
  end

  test "retiring a card still in today's queue takes it out of both sides of the progress fraction (AE14)" do
    child = child_with_cards name: "Nim", due: 12
    day = StudyDay.open_for! child
    day.queue_items.next_up.first(4).each { it.update! cleared_at: Time.current, cleared_reason: :correct }
    retired = day.next_item.card

    retired.update! retired_at: Time.current
    removed = StudyDay.open_today.filter_map { it.remove_card! retired }

    assert_equal ["removed"], removed.map(&:cleared_reason)
    assert_equal 4, day.cleared_count
    assert_equal 7, day.remaining_count
    assert_not_equal retired.id, day.next_item.card_id
  end

  test "retiring a card the child has already cleared leaves the progress fraction alone, a park included" do
    child = child_with_cards name: "Pip", due: 3
    day = StudyDay.open_for! child
    answered, parked = day.queue_items.next_up.first(2)
    answered.update! cleared_at: Time.current, cleared_reason: :correct
    parked.update! cleared_at: Time.current, cleared_reason: :parked

    assert_nil day.remove_card!(answered.card)
    assert_nil day.remove_card!(parked.card)

    assert_equal 2, day.cleared_count
    assert_equal 1, day.remaining_count
    assert_equal %w[correct parked], [answered.reload.cleared_reason, parked.reload.cleared_reason]
  end

  test "a card spread to a later day leaves the queue, and one made due today after first open does not join it" do
    child = child_with_cards name: "Rue", due: 3, unseen: 1, cap: 0
    day = StudyDay.open_for! child
    spread = day.next_item.card
    held_back = child.card_progresses.find_by! due_on: nil

    child.card_progresses.find_by!(card: spread).update! due_on: today + 3
    day.remove_card! spread
    held_back.update! due_on: today

    assert_equal 2, day.remaining_count
    assert_not_includes day.queue_items.map(&:card_id), held_back.card_id
  end

  test "a retired card is left out of the day's queue" do
    child = child_with_cards name: "Dop", due: 2, unseen: 2
    child.decks.sole.cards.order(:position).first.update! retired_at: Time.current

    day = StudyDay.open_for! child

    assert_equal 3, day.queue_items.count
    assert_equal 1, day.due_count_at_open
    assert_equal 2, day.new_count_at_open
  end

  test "a session that crosses midnight opens the new day on its next request" do
    child = child_with_cards name: "Bas", due: 2
    yesterday = StudyDay.open_for! child

    travel_to Time.utc(2026, 9, 14, 23, 30)
    tomorrow = StudyDay.open_for! child

    assert_not_equal yesterday.id, tomorrow.id
    assert_equal Date.new(2026, 9, 15), tomorrow.study_date
    assert_equal 2, tomorrow.queue_items.count
    assert_nil yesterday.reload.done_at
  end

  test "a child with no deck assigned opens a day with an empty queue" do
    child = Child.create! name: "Mar", color: "pink", created_on: today

    day = StudyDay.open_for! child

    assert_equal 0, day.queue_items.count
    assert_equal 0, day.due_count_at_open
    assert_equal 0, day.new_count_at_open
    assert_nil day.next_item
  end

  test "reopening returns the same next card and the same progress" do
    child = child_with_cards name: "Sne", due: 3
    day = StudyDay.open_for! child
    day.queue_items.order(:sort_key).first.update! cleared_at: Time.current, cleared_reason: :correct
    expected = day.next_item

    reopened = StudyDay.open_for! child

    assert_equal day.id, reopened.id
    assert_equal expected.id, reopened.next_item.id
    assert_equal 1, reopened.cleared_count
    assert_equal 2, reopened.remaining_count
  end

  test "a card answered wrong moves to the back on its timestamp, leaving the frozen sort keys alone" do
    child = child_with_cards name: "Tam", due: 3
    day = StudyDay.open_for! child
    wrong, following = day.queue_items.next_up.first(2)

    wrong.update! last_wrong_at: Time.current, wrong_count: 1

    assert_equal following.id, day.next_item.id
    assert_equal wrong.id, day.queue_items.next_up.last.id
    assert_equal [1, 2, 3], day.queue_items.order(:sort_key).map(&:sort_key)
  end

  test "the queue is ordered by deck assignment position then card position, with the day's new cards last" do
    child = Child.create! name: "Mar", color: "pink", created_on: today
    second = Deck.create! name: "Second deck"
    first = Deck.create! name: "First deck"
    child.deck_assignments.create! deck: second, position: 2
    child.deck_assignments.create! deck: first, position: 1

    cards = {}
    {"S" => second, "F" => first}.each do |tag, deck|
      [2, 1].each do |position|
        cards["#{tag}#{position}"] = deck.cards.create! position:, prompt: "#{tag} #{position} + 0", accepted_answers: ["1"]
      end
    end
    %w[F1 S1].each { child.card_progresses.find_by!(card: cards[it]).update! due_on: today }

    day = StudyDay.open_for! child

    assert_equal cards.values_at("F1", "S1", "F2", "S2").map(&:id), day.queue_items.order(:sort_key).map(&:card_id)
    assert_equal %w[review review new new], day.queue_items.order(:sort_key).map(&:source)
    assert_equal [1, 2, 3, 4], day.queue_items.order(:sort_key).map(&:sort_key)
  end

  test "settling twice in succession records one done, because the second guarded update affects no row" do
    child = child_with_cards name: "Fin", due: 2
    day = StudyDay.open_for! child
    day.queue_items.next_up.first.clear! :correct

    assert_not day.settle!, "a day with a card left in the queue is not done"

    day.next_item.clear! :parked

    assert day.settle!
    done_at = day.reload.done_at
    travel 1.minute

    assert_not day.settle!
    assert_equal done_at, day.reload.done_at
  end

  test "clearing the last card records done once, with the household date" do
    child = child_with_cards name: "Cle", due: 1
    day = StudyDay.open_for! child

    day.next_item.show!.answer! "0"

    assert_equal Date.new(2026, 9, 14), day.study_date
    assert_equal Time.utc(2026, 9, 13, 23, 30), day.done_at
    assert_equal day.done_at, day.reload.done_at

    travel 1.minute

    assert_not day.settle!, "a day that is already done settles no second time"
    assert_equal Time.utc(2026, 9, 13, 23, 30), day.reload.done_at
  end

  test "a first open with nothing due and nothing admitted records done at that moment (AE6)" do
    child = child_with_cards name: "Emp", unseen: 2, cap: 0

    day = StudyDay.open_for! child

    assert_equal 0, day.queue_items.count
    assert_equal 0, day.new_count_at_open
    assert_equal Time.utc(2026, 9, 13, 23, 30), day.done_at
    assert_equal day.done_at, day.reload.done_at
  end

  test "a day whose queue cannot be written is not left claimed, and the next open assembles it" do
    child = child_with_cards name: "Fai", due: 2, unseen: 2, cap: 2

    failing QueueItem, :insert_all do
      assert_raises(ActiveRecord::StatementInvalid) { StudyDay.open_for! child }
    end

    stranded = child.study_days.sole
    assert_nil stranded.first_opened_at
    assert_equal 0, stranded.queue_items.count
    assert_equal 2, child.card_progresses.where(due_on: nil).count, "intake rolls back with the claim"

    reopened = StudyDay.open_for! child

    assert_not_nil reopened.first_opened_at
    assert_equal 4, reopened.queue_items.count
    assert_equal [2, 2], [reopened.due_count_at_open, reopened.new_count_at_open]
  end

  test "the first open that loses the claim reads back the day the winner assembled" do
    child = child_with_cards name: "Los", unseen: 2, cap: 0
    child.study_days.create! study_date: today
    winner, loser = 2.times.map { child.study_days.find_by! study_date: today }

    winner.open!

    assert_not_nil loser.open!.done_at
  end

  test "a day the child never opens records nothing at all (AE6)" do
    child = child_with_cards name: "Gap", due: 2

    travel_to Time.utc(2026, 9, 14, 23, 30)
    StudyDay.open_for! child

    assert_equal [Date.new(2026, 9, 15)], child.study_days.pluck(:study_date)
  end

  test "an agent removing the last card the child had left records done at that moment (AE16)" do
    child = child_with_cards name: "Rem", due: 2
    day = StudyDay.open_for! child
    answered, left = day.queue_items.next_up.to_a
    answered.show!.answer! "0"

    assert_nil day.done_at

    travel 2.minutes
    removed = day.remove_card! left.card

    assert_equal "removed", removed.cleared_reason
    assert_equal Time.utc(2026, 9, 13, 23, 32), day.done_at
    assert_equal 1, day.cleared_count
    assert_equal 0, day.remaining_count
  end

  test "done at 08:30 Tokyo time on a UTC server is recorded for the Tokyo date (AE7)" do
    child = child_with_cards name: "Zon", due: 1
    assert_equal Date.new(2026, 9, 13), Time.now.utc.to_date

    day = Time.use_zone("UTC") { StudyDay.open_for!(child).tap { it.next_item.show!.answer! "0" } }

    assert_equal Date.new(2026, 9, 14), day.study_date
    assert_equal Time.utc(2026, 9, 13, 23, 30), day.done_at
    assert_equal day.id, child.study_days.find_by!(study_date: Date.new(2026, 9, 14)).id
  end

  private

  # Nothing in the bundle stubs, and the failure these cover is a write that raises part-way
  # through the day: SQLite's busy timeout while an operation holds the write lock.
  def failing(klass, method)
    klass.define_singleton_method(method) { |*, **| raise ActiveRecord::StatementInvalid, "database is locked" }
    yield
  ensure
    klass.singleton_class.send :remove_method, method
  end

  def today
    Household.with_zone { Date.current }
  end

  def child_with_cards(name:, due: 0, unseen: 0, cap: 5, threshold: 10)
    child = Child.create! name:, color: "pink", created_on: today, new_card_cap: cap, light_day_threshold: threshold
    deck = Deck.create! name: "#{name}'s deck"
    child.deck_assignments.create! deck:, position: 1

    (due + unseen).times do |index|
      card = deck.cards.create! position: index + 1, prompt: "#{name} #{index} + 0", accepted_answers: [index.to_s]
      child.card_progresses.find_by!(card:).update! due_on: today if index < due
    end

    child
  end
end
