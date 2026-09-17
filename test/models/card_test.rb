require "test_helper"

# == Schema Information
#
# Table name: cards
#
#  id               :integer          not null, primary key
#  accepted_answers :json             not null
#  accepted_keys    :json             not null
#  content_digest   :string           not null
#  position         :integer          not null
#  prompt           :text             not null
#  prompt_key       :string           not null
#  retired_at       :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  deck_id          :integer          not null
#
# Indexes
#
#  index_cards_on_deck_id_and_position    (deck_id,position)
#  index_cards_on_deck_id_and_prompt_key  (deck_id,prompt_key) UNIQUE WHERE retired_at IS NULL
#
# Foreign Keys
#
#  deck_id  (deck_id => decks.id)
#
class CardTest < ActiveSupport::TestCase
  test "writes the prompt key, accepted keys, and digest from the normalizers on create" do
    card = decks(:tables).cards.create! position: 2, prompt: "  ７ × ８  ", accepted_answers: ["０５６"]

    assert_equal "7×8", card.prompt_key
    assert_equal ["56"], card.accepted_keys
    assert_equal Normalize.digest("7×8", ["56"]), card.content_digest
  end

  test "writes the prompt key, accepted keys, and digest from the normalizers on update" do
    card = cards(:sum_23_19)
    card.update! prompt: "23+19"

    assert_equal "23+19", card.prompt_key
    assert_equal Normalize.digest("23+19", ["42"]), card.content_digest

    card.update! prompt: "27 + 15"

    assert_equal "27+15", card.prompt_key
    assert_not_equal Normalize.digest("23+19", ["42"]), card.content_digest
  end

  # AE12
  test "deleting a card that has attempts is refused" do
    card = cards(:sum_38_27)
    assert card.attempts.any?

    assert_no_difference -> { Card.count } do
      assert_not card.destroy
    end
    assert card.errors[:base].any?
  end

  # AE12
  test "deleting a card that has no attempts succeeds" do
    card = cards(:times_6_7)
    assert_empty card.attempts

    assert_difference -> { Card.count }, -1 do
      assert card.destroy
    end
  end

  test "two cards whose prompts differ only by spacing cannot coexist unretired in one deck" do
    duplicate = decks(:addition).cards.new position: 9, prompt: "23+19", accepted_answers: ["42"]

    assert_not duplicate.valid?
    assert duplicate.errors[:prompt_key].any?
  end

  test "the same prompt can exist again once the first card is retired" do
    cards(:sum_23_19).update! retired_at: Time.current

    assert decks(:addition).cards.create!(position: 9, prompt: "23 + 19", accepted_answers: ["42"]).persisted?
  end

  test "the same prompt in another deck is accepted" do
    assert decks(:tables).cards.create!(position: 9, prompt: "23 + 19", accepted_answers: ["42"]).persisted?
  end

  test "a card with no accepted answer is invalid" do
    card = decks(:tables).cards.new position: 9, prompt: "9 + 9", accepted_answers: []

    assert_not card.valid?
    assert card.errors[:accepted_answers].any?
  end

  test "a card whose only accepted answer normalizes away is invalid" do
    card = decks(:tables).cards.new position: 9, prompt: "9 + 9", accepted_answers: [" "]

    assert_not card.valid?
    assert card.errors[:accepted_keys].any?
  end

  test "adding a card to an assigned deck creates a progress row with no due date for each assigned child" do
    card = decks(:addition).cards.create! position: 9, prompt: "9 + 9", accepted_answers: ["18"]

    assert_equal [children(:pau), children(:teo)].sort_by(&:id), card.card_progresses.map(&:child).sort_by(&:id)
    assert card.card_progresses.all? { it.due_on.nil? }
  end
end
