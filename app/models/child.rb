# == Schema Information
#
# Table name: children
#
#  id                  :integer          not null, primary key
#  color               :string           not null
#  created_on          :date             not null
#  light_day_threshold :integer          default(10), not null
#  name                :string           not null
#  new_card_cap        :integer          default(5), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_children_on_name  (name) UNIQUE
#
# Check Constraints
#
#  light_day_threshold_leaves_room  (light_day_threshold >= 1)
#  new_card_cap_is_not_negative     (new_card_cap >= 0)
#
class Child < ApplicationRecord
  # The Home Screen icon is a checked-in PNG per name and the manifest needs the hex,
  # so a color cannot be a free-form CSS value. Every one of these is dark enough to hold
  # a QR code against white. The floor is roughly 3:1 — below that a camera will not read the
  # code off a laptop screen held at arm's length, which is what these are scanned from.
  COLORS = {
    "blue" => "#2f6fed",
    "green" => "#1f9d55",
    "orange" => "#e8710a",
    "pink" => "#e0409a",
    "purple" => "#7b4fd1",
    "red" => "#d93a2b",
    "teal" => "#0f9b9b"
  }.freeze

  # The same seven hues, lightened and desaturated for a dark ground. At full saturation the
  # child's color is right on a pale ground and wrong on a dark one: blue lands at about 3.1:1
  # there, which carries an 84px answer and not a 30px star. Adding a color means adding it to
  # both constants, which the test holds them to.
  COLORS_DARK = {
    "blue" => "#7ea6ff",
    "green" => "#7fc79b",
    "orange" => "#f0a463",
    "pink" => "#f08dc0",
    "purple" => "#b393e8",
    "red" => "#ef8b7f",
    "teal" => "#5fc2c2"
  }.freeze

  has_many :attempts, dependent: :restrict_with_error
  has_many :card_progresses, dependent: :destroy
  has_many :deck_assignments, dependent: :destroy
  has_many :decks, through: :deck_assignments
  has_many :devices, dependent: :destroy
  has_many :pairing_links, dependent: :destroy
  has_many :study_days, dependent: :destroy

  validates :color, presence: true, inclusion: {in: COLORS.keys}
  validates :created_on, presence: true
  validates :light_day_threshold, numericality: {only_integer: true, greater_than_or_equal_to: 1}
  validates :name, presence: true, uniqueness: true
  validates :new_card_cap, numericality: {only_integer: true, greater_than_or_equal_to: 0}
  validate :new_card_cap_within_light_day_threshold

  # The child's progress on every card they are studying, in the order they meet them: deck by
  # the order the decks were assigned to them, card by the position the agent gave it in its
  # deck. Unassigning a deck takes its cards out of here and leaves the progress rows behind,
  # so re-assigning resumes from the due dates they kept.
  def assigned_progresses
    card_progresses
      .joins(card: {deck: :deck_assignments})
      .where(cards: {retired_at: nil}, deck_assignments: {child_id: id, unassigned_at: nil})
      .order("deck_assignments.position", "cards.position")
  end

  def color_hex
    COLORS.fetch color
  end

  def color_hex_dark
    COLORS_DARK.fetch color
  end

  private

  def new_card_cap_within_light_day_threshold
    return if new_card_cap.blank? || light_day_threshold.blank?
    return if new_card_cap <= light_day_threshold

    errors.add :new_card_cap, "cannot be greater than the light day threshold"
  end
end
