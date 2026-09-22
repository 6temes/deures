# == Schema Information
#
# Table name: pairing_links
#
#  id           :integer          not null, primary key
#  claimed_at   :datetime
#  expires_at   :datetime         not null
#  revoked_at   :datetime
#  token_digest :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  child_id     :integer          not null
#
# Indexes
#
#  index_pairing_links_on_child_id      (child_id)
#  index_pairing_links_on_token_digest  (token_digest) UNIQUE
#
# Foreign Keys
#
#  child_id  (child_id => children.id)
#
class PairingLink < ApplicationRecord
  # Long enough to carry the iPad from the console printing the code to Add to Home Screen,
  # and short enough that a URL seen over a shoulder is spent by the time it is typed.
  WINDOW = 15.minutes

  belongs_to :child

  has_many :devices, dependent: :destroy

  include Tokenized

  scope :live, -> { where(claimed_at: nil, revoked_at: nil).where(expires_at: Time.current..) }

  before_validation :open_window, on: :create

  validates :expires_at, presence: true

  def claim!
    update! claimed_at: Time.current
  end

  def claimed?
    claimed_at.present?
  end

  def expired?
    expires_at.past?
  end

  def pair!
    transaction { devices.create!.tap { claim! } }
  end

  def revoke!
    update! revoked_at: Time.current
  end

  def revoked?
    revoked_at.present?
  end

  # The claiming device is still allowed through, because the install view it has just been
  # rendered fetches the manifest and both icons with this same token straight after the claim.
  def usable_by?(device)
    return false if expired? || revoked?

    !claimed? || device&.pairing_link_id == id
  end

  private

  def open_window
    self.expires_at ||= WINDOW.from_now
  end
end
