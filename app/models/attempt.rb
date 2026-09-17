# == Schema Information
#
# Table name: attempts
#
#  id                :integer          not null, primary key
#  accepted_keys     :json             not null
#  answer            :text             not null
#  answer_key        :string           not null
#  attempt_index     :integer          not null
#  prompt            :text             not null
#  seconds_to_answer :float            not null
#  showing_token     :string           not null
#  study_date        :date             not null
#  verdict           :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  card_id           :integer
#  child_id          :integer          not null
#
# Indexes
#
#  index_attempts_on_card_id                  (card_id)
#  index_attempts_on_child_id_and_study_date  (child_id,study_date)
#  index_attempts_on_lapses                   (child_id,card_id,study_date) WHERE attempt_index = 1 AND verdict = 'wrong'
#  index_attempts_on_showing_token            (showing_token) UNIQUE
#
# Foreign Keys
#
#  card_id   (card_id => cards.id)
#  child_id  (child_id => children.id)
#
# Check Constraints
#
#  attempt_index_is_positive          (attempt_index >= 1)
#  seconds_to_answer_is_not_negative  (seconds_to_answer >= 0)
#
class Attempt < ApplicationRecord
  belongs_to :card, optional: true
  belongs_to :child

  before_validation :derive_answer_key, on: :create
  before_destroy :refuse_destroy

  enum :verdict, %w[correct wrong].index_by(&:itself)

  normalizes :answer_key, with: ->(value) { Normalize.answer(value) }

  # The log is append-only. This holds at the model layer only: update_column,
  # insert_all and the database itself all go straight past it.
  attr_readonly :accepted_keys, :answer, :answer_key, :attempt_index, :card_id, :child_id,
    :created_at, :prompt, :seconds_to_answer, :showing_token, :study_date,
    :updated_at, :verdict

  validates :accepted_keys, presence: true
  validates :answer, presence: true
  validates :answer_key, presence: true
  validates :attempt_index, numericality: {only_integer: true, greater_than_or_equal_to: 1}
  validates :prompt, presence: true
  validates :seconds_to_answer, numericality: {greater_than_or_equal_to: 0}
  validates :showing_token, presence: true, uniqueness: true
  validates :study_date, presence: true
  validates :verdict, presence: true

  private

  def derive_answer_key
    self.answer_key = answer
  end

  def refuse_destroy
    errors.add :base, "attempts are append-only and cannot be deleted"
    throw :abort
  end
end
