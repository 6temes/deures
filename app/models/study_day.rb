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
class StudyDay < ApplicationRecord
  belongs_to :child

  has_many :queue_items, dependent: :destroy

  scope :open_today, -> { Household.with_zone { where(study_date: Date.current) } }

  validates :child_id, uniqueness: {scope: :study_date}
  validates :study_date, presence: true

  def self.open_for!(child)
    Household.with_zone do
      study_date = Date.current

      # The row is only created here; open! is what claims it. The insert does nothing on
      # conflict, so a day the agent excused before the child opened it and two concurrent first
      # requests all arrive at the same guarded claim. find_or_create_by reads before it writes,
      # and admits new cards twice.
      insert_all [{child_id: child.id, study_date:}], unique_by: %i[child_id study_date]

      child.study_days.find_by!(study_date:).open!
    end
  end

  # The claim and the assembly are one transaction, and the claim is the affected-row count of
  # the guarded update the same way done is. An assembly that cannot finish takes the claim back
  # with it, so the next request assembles the day rather than finding one that says it is open
  # and holds no queue. Skipped once the day is open, so every later request costs no write.
  def open!
    return self if first_opened_at

    transaction do
      now = Time.current
      claimed = self.class.where(id:, first_opened_at: nil).update_all(first_opened_at: now, updated_at: now) == 1

      # The loser of two concurrent first opens waits out the winner's write lock to reach this,
      # so what it hands back is the assembled day and not the empty row it read a moment ago.
      claimed ? reload.assemble! : reload
    end
  end

  def assemble!
    reviews = due_progresses.to_a
    admitted = admit_new_cards reviews.size

    write_queue reviews, admitted
    update! due_count_at_open: reviews.size, new_count_at_open: admitted.size
    # Nothing due and nothing admitted is a day that is over as soon as it is assembled: no
    # answer is coming later to settle it.
    settle!
    self
  end

  def next_item
    queue_items.next_up.first
  end

  def cleared_count
    queue_items.cleared_by_child.count
  end

  def remaining_count
    queue_items.uncleared.count
  end

  # Done is claimed by the update's own where clause rather than by the read above it: two
  # requests that empty the queue at the same moment both find it empty, and the affected-row
  # count is the only thing that decides between them.
  def settle!
    return false if queue_items.uncleared.exists?

    now = Time.current
    claimed = self.class.where(id:, done_at: nil).update_all(done_at: now, updated_at: now) == 1
    # The request that settles the day is the one that renders the done screen, and it renders
    # from this object rather than from a re-read of the row.
    self.done_at = now if claimed
    claimed
  end

  # The celebration is claimed the same guarded way done is, so the first render of the done
  # screen takes it and every later one that day finds it gone. A day that is not done has
  # nothing to claim, which is what the done_at clause says.
  def claim_celebration!
    now = Time.current

    self.class.where(id:, done_seen_at: nil).where.not(done_at: nil)
      .update_all(done_seen_at: now, updated_at: now) == 1
  end

  # An item the child has already cleared keeps the reason it was cleared with: dropping
  # it from the progress numerator would move progress backwards.
  def remove_card!(card)
    queue_items.uncleared.find_by(card:)&.tap(&:remove!)
  end

  private

  def due_progresses
    child.assigned_progresses.where(due_on: ..study_date)
  end

  # New cards are admitted at the first open alone, and only onto a light day: enough to
  # reach the cap, or to fill the queue to the threshold, whichever comes first.
  def admit_new_cards(due_count)
    room = [child.new_card_cap, child.light_day_threshold - due_count].min
    return [] if room < 1

    child.assigned_progresses.where(due_on: nil).limit(room).to_a.each { it.update! due_on: study_date }
  end

  def write_queue(reviews, admitted)
    sourced = reviews.map { [it, "review"] } + admitted.map { [it, "new"] }
    return if sourced.empty?

    now = Time.current
    rows = sourced.each_with_index.map do |(progress, source), index|
      {study_day_id: id, card_id: progress.card_id, sort_key: index + 1, source:, created_at: now, updated_at: now}
    end

    QueueItem.insert_all rows
  end
end
