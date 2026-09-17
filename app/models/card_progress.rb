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
class CardProgress < ApplicationRecord
  # `rung` counts the rungs climbed, not days: 0 is the bottom, where a new card and a
  # lapsed one both sit, and rung n means the card is due INTERVALS[n - 1] days out.
  INTERVALS = [1, 2, 4, 8, 16, 32].freeze

  belongs_to :card
  belongs_to :child

  validates :card_id, uniqueness: {scope: :child_id}
  validates :rung, numericality: {only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: INTERVALS.size}

  # Idempotent by the unique index: a pair that already has a row keeps the rung and the due
  # date it holds, which is what lets a re-assigned deck resume rather than start every card over.
  def self.create_missing(card_ids:, child_ids:)
    now = Time.current
    rows = card_ids.product(child_ids).map { |card_id, child_id| {card_id:, child_id:, created_at: now, updated_at: now} }
    return if rows.empty?

    insert_all rows, unique_by: %i[child_id card_id]
  end

  def climb!(on:)
    next_rung = [rung + 1, INTERVALS.size].min

    update! rung: next_rung, due_on: on + INTERVALS[next_rung - 1], last_answered_on: on
  end

  # A lapse costs the whole ladder, so the next correct first answer earns one day again, as
  # on a card the child has never seen.
  def lapse!(on:)
    update! rung: 0, due_on: on + 1, last_answered_on: on
  end

  # The flag the agent's reads list a stuck card by. The schedule belongs to the lapse the
  # day's first wrong answer already applied; a park adds nothing to it.
  def park!(on:)
    update! parked_on: on
  end

  # Answering it right is the only thing that says the card stopped being a problem, whichever
  # attempt of the day that is.
  def unpark!
    update! parked_on: nil
  end
end
