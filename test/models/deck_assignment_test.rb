require "test_helper"

# == Schema Information
#
# Table name: deck_assignments
#
#  id            :integer          not null, primary key
#  position      :integer          not null
#  unassigned_at :datetime
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  child_id      :integer          not null
#  deck_id       :integer          not null
#
# Indexes
#
#  index_deck_assignments_on_child_id_and_deck_id  (child_id,deck_id) UNIQUE
#  index_deck_assignments_on_deck_id               (deck_id)
#
# Foreign Keys
#
#  child_id  (child_id => children.id)
#  deck_id   (deck_id => decks.id)
#
class DeckAssignmentTest < ActiveSupport::TestCase
  test "assigning a deck to a child creates a progress row per card with no due date" do
    child = Child.create! name: "Mar", color: "pink", created_on: Date.new(2026, 9, 14)
    deck = decks(:addition)

    assert_difference -> { CardProgress.count }, deck.cards.count do
      child.deck_assignments.create! deck:, position: 1
    end
    assert_equal deck.cards.sort_by(&:id), child.card_progresses.map(&:card).sort_by(&:id)
    assert child.card_progresses.all? { it.due_on.nil? }
  end

  test "re-assigning a deck keeps the progress a child already has" do
    assignment = deck_assignments(:pau_addition)
    progress = card_progresses(:pau_sum_23_19)
    assignment.update! unassigned_at: Time.current

    assert_no_difference -> { CardProgress.count } do
      assignment.update! unassigned_at: nil
    end
    assert_equal Date.new(2026, 9, 14), progress.reload.due_on
  end

  test "a deck cannot be assigned to the same child twice" do
    duplicate = children(:pau).deck_assignments.new deck: decks(:addition), position: 3

    assert_not duplicate.valid?
    assert duplicate.errors[:deck_id].any?
  end
end
