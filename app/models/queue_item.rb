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
class QueueItem < ApplicationRecord
  # The third wrong answer of the day parks the card instead of sending it back to the queue,
  # so one card the child cannot do can never hold the day open.
  WRONG_LIMIT = 3

  belongs_to :card, optional: true
  belongs_to :study_day

  enum :cleared_reason, %w[correct parked removed].index_by(&:itself), prefix: :cleared
  enum :source, %w[new review].index_by(&:itself), prefix: true

  # The numerator of the progress the child sees. An item the agent removed counts on
  # neither side of that fraction, so a removal never moves progress backwards.
  scope :cleared_by_child, -> { where(cleared_reason: %w[correct parked]) }
  # A wrong answer sends its card to the back by stamping last_wrong_at, never by
  # rewriting a sort key: the key is frozen at assembly, so unstamped items sort first.
  scope :next_up, -> { uncleared.order(arel_table[:last_wrong_at].asc.nulls_first, :sort_key) }
  scope :uncleared, -> { where(cleared_at: nil) }

  validates :card_id, uniqueness: {scope: :study_day_id}, if: :card_id?
  validates :showing_token, uniqueness: true, allow_nil: true
  validates :sort_key, presence: true
  validates :source, presence: true
  validates :wrong_count, numericality: {only_integer: true, greater_than_or_equal_to: 0}

  # The attempt is written before anything is graded, and its unique index on the showing token
  # is the whole of the idempotency: a double tap and a retried submit carry the same token, so
  # the second of them replays the verdict the first one recorded instead of grading again. The
  # attempt and its effects are written together, because the replay is what the retry of a
  # half-applied answer gets and it applies nothing itself.
  def answer!(typed)
    attempt = build_attempt typed

    transaction do
      unless attempt.save
        # A taken showing token is the only failure with a verdict behind it. Anything else is a
        # submit nothing has graded, and replaying it would look for an attempt never written.
        raise ActiveRecord::RecordInvalid, attempt unless attempt.errors.of_kind?(:showing_token, :taken)

        next replayed_attempt
      end

      apply attempt
      attempt
    end
  rescue ActiveRecord::RecordNotUnique
    replayed_attempt
  end

  # An item the agent has already removed keeps the reason it was cleared with, so a late
  # answer to it cannot move the progress fraction the day recorded.
  def clear!(reason)
    return if cleared?

    update! cleared_at: Time.current, cleared_reason: reason
  end

  def cleared?
    cleared_at.present?
  end

  # A removal is a clear with its own reason rather than a delete, so the counts the day
  # recorded at its first open still reconcile against its rows. Taking the last card the
  # child had left ends the day, so a removal settles it exactly as an answer does.
  def remove!
    clear_and_settle! :removed
  end

  # Every render is a new showing, a reopen included: the token an answer carries back is unique
  # on attempts, its seconds are measured from the stamp, and the snapshot is the card as the
  # child saw it, whatever the agent does to the card afterwards.
  def show!
    update! showing_token: SecureRandom.urlsafe_base64(16),
      shown_accepted_keys: card.accepted_keys,
      shown_at: Time.current,
      shown_prompt: card.prompt

    self
  end

  private

  def build_attempt(typed)
    study_day.child.attempts.new(
      accepted_keys: shown_accepted_keys,
      answer: typed,
      attempt_index: next_attempt_index,
      card_id:,
      prompt: shown_prompt,
      seconds_to_answer: Time.current - shown_at,
      showing_token:,
      study_date: study_day.study_date,
      verdict: shown_accepted_keys.include?(Normalize.answer(typed)) ? :correct : :wrong
    )
  end

  def next_attempt_index
    Attempt.where(card_id:, child_id: study_day.child_id, study_date: study_day.study_date).count + 1
  end

  def replayed_attempt
    Attempt.find_by! showing_token:
  end

  def apply(attempt)
    move_schedule attempt if attempt.attempt_index == 1
    return record_wrong unless attempt.correct?

    progress&.unpark!
    clear_and_settle! :correct
  end

  # A wrong answer goes to the back of the queue by stamping the time rather than by rewriting
  # sort keys, so the order the rest of the queue was assembled in survives it.
  def record_wrong
    update! last_wrong_at: Time.current, wrong_count: wrong_count + 1
    return if wrong_count < WRONG_LIMIT

    progress&.park! on: study_day.study_date
    clear_and_settle! :parked
  end

  # Only a card's first answer of the day moves its schedule: a card answered wrong and then
  # right on the same day would otherwise be both reset to tomorrow and moved up a rung.
  def move_schedule(attempt)
    return unless progress

    attempt.correct? ? progress.climb!(on: study_day.study_date) : progress.lapse!(on: study_day.study_date)
  end

  # The card can be gone by now: deleting one nullifies this item and takes the progress row
  # with it, while the attempt is still recorded against the snapshot the child answered.
  def progress
    @_progress ||= CardProgress.find_by card_id:, child_id: study_day.child_id
  end

  # SQLite has no row locks, so `lock!` would emit a plain select and hold nothing. The write
  # lock the adapter takes when it opens the transaction as BEGIN IMMEDIATE is the real mutual
  # exclusion, and the day is re-read inside it because dropping the lock drops its reload too.
  def clear_and_settle!(reason)
    transaction do
      clear! reason
      study_day.reload.settle!
    end
  end
end
