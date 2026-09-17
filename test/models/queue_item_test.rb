require "test_helper"

# == Schema Information
#
# Table name: queue_items
#
#  id                  :integer          not null, primary key
#  cleared_at          :datetime
#  cleared_reason      :string
#  last_wrong_at       :datetime
#  showing_token       :string
#  shown_accepted_keys :json
#  shown_at            :datetime
#  shown_prompt        :text
#  sort_key            :integer          not null
#  source              :string           not null
#  wrong_count         :integer          default(0), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  card_id             :integer
#  study_day_id        :integer          not null
#
# Indexes
#
#  index_queue_items_on_card_id                   (card_id)
#  index_queue_items_on_showing_token             (showing_token) UNIQUE
#  index_queue_items_on_study_day_id_and_card_id  (study_day_id,card_id) UNIQUE
#
# Foreign Keys
#
#  card_id       (card_id => cards.id) ON DELETE => nullify
#  study_day_id  (study_day_id => study_days.id)
#
# Check Constraints
#
#  wrong_count_is_not_negative  (wrong_count >= 0)
#
class QueueItemTest < ActiveSupport::TestCase
  test "holds the prompt and accepted keys it was last shown with, whatever the card says later" do
    item = queue_items(:pau_sum_23_19)
    item.card.update! prompt: "27 + 15", accepted_answers: ["42", "0042"]

    assert_equal "23 + 19", item.reload.shown_prompt
    assert_equal ["42"], item.shown_accepted_keys
  end

  test "keeps its showing snapshot with no card when a never-attempted card is deleted" do
    item = queue_items(:pau_sum_23_19)
    item.card.destroy!

    assert_nil item.reload.card_id
    assert_equal "23 + 19", item.shown_prompt
    assert_equal ["42"], item.shown_accepted_keys
    assert_equal "showing-pau-23-19", item.showing_token
  end

  test "one card appears at most once in a study day" do
    duplicate = study_days(:pau_today).queue_items.new card: cards(:sum_23_19), sort_key: 3, source: "review"

    assert_not duplicate.valid?
    assert duplicate.errors[:card_id].any?
  end

  test "several items with no card can share a study day" do
    study_days(:pau_today).queue_items.create! sort_key: 3, source: "review"

    assert study_days(:pau_today).queue_items.create!(sort_key: 4, source: "new").persisted?
  end

  test "a submit that fails a validation other than the showing token raises rather than replaying" do
    item = queue_items(:pau_sum_23_19).show!
    item.update! shown_at: 1.hour.from_now

    assert_raises ActiveRecord::RecordInvalid do
      item.answer! "42"
    end
  end

  test "an answer whose effects cannot be written records no attempt, so the retry grades it again" do
    item = queue_items(:pau_sum_23_19).show!

    failing CardProgress, :find_by do
      assert_raises(ActiveRecord::StatementInvalid) { item.answer! "41" }
    end

    assert_nil Attempt.find_by(showing_token: item.showing_token), "the attempt rolls back with its effects"

    item.answer! "41"

    assert_equal 1, item.reload.wrong_count
    assert_equal 0, card_progresses(:pau_sum_23_19).reload.rung
  end

  test "two items cannot share a showing token" do
    duplicate = study_days(:pau_today).queue_items.new(
      card: cards(:difference_7_7),
      sort_key: 3,
      source: "review",
      showing_token: queue_items(:pau_sum_23_19).showing_token
    )

    assert_not duplicate.valid?
    assert duplicate.errors[:showing_token].any?
  end

  private

  # Nothing in the bundle stubs, and the failure this covers is a write that raises between the
  # attempt and its effects: SQLite's busy timeout while an operation holds the write lock.
  def failing(klass, method)
    klass.define_singleton_method(method) { |*, **| raise ActiveRecord::StatementInvalid, "database is locked" }
    yield
  ensure
    klass.singleton_class.send :remove_method, method
  end
end
