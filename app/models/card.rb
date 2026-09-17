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
class Card < ApplicationRecord
  belongs_to :deck

  has_many :attempts, dependent: :restrict_with_error
  has_many :card_progresses, dependent: :destroy
  has_many :queue_items, dependent: :nullify

  before_validation :derive_content_keys
  after_create :create_card_progresses

  normalizes :prompt_key, with: ->(value) { Normalize.prompt(value) }
  normalizes :accepted_keys, with: ->(values) { Array(values).map { Normalize.answer(it) } }

  validates :accepted_answers, presence: true
  # Derived from accepted_answers. A blank key is as unanswerable as no key at all, and
  # presence alone lets one through: Normalize.answer(" ") is "", and [ "" ] is present.
  validates :accepted_keys, presence: true
  validate :accepted_keys_are_answerable
  validates :content_digest, presence: true
  validates :position, presence: true
  validates :prompt, presence: true
  validates :prompt_key, presence: true
  validates :prompt_key, uniqueness: {scope: :deck_id, conditions: -> { where(retired_at: nil) }}, unless: :retired?

  def retired?
    retired_at.present?
  end

  private

  def derive_content_keys
    self.prompt_key = prompt
    self.accepted_keys = accepted_answers
    self.content_digest = Normalize.digest prompt_key, Array(accepted_keys)
  end

  def accepted_keys_are_answerable
    errors.add :accepted_keys, "cannot contain a blank answer" if Array(accepted_keys).any?(&:blank?)
  end

  def create_card_progresses
    CardProgress.create_missing card_ids: [id], child_ids: DeckAssignment.assigned.where(deck_id:).pluck(:child_id)
  end
end
