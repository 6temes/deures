require "test_helper"

# == Schema Information
#
# Table name: card_progresses
#
#  id               :integer          not null, primary key
#  due_on           :date
#  last_answered_on :date
#  parked_on        :date
#  rung             :integer          default(0), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  card_id          :integer          not null
#  child_id         :integer          not null
#
# Indexes
#
#  index_card_progresses_on_card_id               (card_id)
#  index_card_progresses_on_child_id_and_card_id  (child_id,card_id) UNIQUE
#  index_card_progresses_on_child_id_and_due_on   (child_id,due_on) WHERE due_on IS NOT NULL
#
# Foreign Keys
#
#  card_id   (card_id => cards.id)
#  child_id  (child_id => children.id)
#
# Check Constraints
#
#  rung_is_on_the_ladder  (rung >= 0 AND rung <= 6)
#
class CardProgressTest < ActiveSupport::TestCase
  test "a child has at most one progress row per card" do
    duplicate = children(:pau).card_progresses.new card: cards(:sum_23_19)

    assert_not duplicate.valid?
    assert duplicate.errors[:card_id].any?
  end

  test "a new card is the one with no due date" do
    assert_nil card_progresses(:pau_difference_7_7).due_on
    assert_equal 0, card_progresses(:pau_difference_7_7).rung
  end

  test "a new card answered correctly is due tomorrow, and the top rung stays thirty-two days out (AE4)" do
    today = Date.new(2026, 9, 14)
    unseen = card_progresses(:pau_difference_7_7)
    mature = card_progresses(:pau_sum_23_19)
    mature.update! rung: CardProgress::INTERVALS.size

    unseen.climb! on: today
    mature.climb! on: today

    assert_equal 1, unseen.rung
    assert_equal today + 1, unseen.due_on
    assert_equal CardProgress::INTERVALS.size, mature.rung
    assert_equal today + 32, mature.due_on
  end

  test "a rung beyond the top of the ladder is invalid" do
    progress = card_progresses(:pau_sum_23_19)
    progress.rung = CardProgress::INTERVALS.size + 1

    assert_not progress.valid?
    assert progress.errors[:rung].any?
  end

  # The check constraint hard-codes the number INTERVALS decides. A seventh interval without a
  # migration would make climb! raise from inside an answer, on a child's iPad, mid-session.
  test "the database bounds the rung where INTERVALS does" do
    constraint = CardProgress.connection.check_constraints("card_progresses")
      .find { it.name == "rung_is_on_the_ladder" }

    assert_equal "rung >= 0 AND rung <= #{CardProgress::INTERVALS.size}", constraint.expression
  end
end
