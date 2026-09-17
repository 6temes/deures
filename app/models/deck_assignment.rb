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
class DeckAssignment < ApplicationRecord
  belongs_to :child
  belongs_to :deck

  after_save :create_card_progresses, if: :assigned?

  scope :assigned, -> { where(unassigned_at: nil) }

  validates :deck_id, uniqueness: {scope: :child_id}
  validates :position, presence: true

  def assigned?
    unassigned_at.nil?
  end

  private

  def create_card_progresses
    CardProgress.create_missing card_ids: deck.cards.pluck(:id), child_ids: [child_id]
  end
end
