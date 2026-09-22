# == Schema Information
#
# Table name: pairing_links
#
#  id         :integer          not null, primary key
#  revoked_at :datetime
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  child_id   :integer          not null
#
# Indexes
#
#  index_pairing_links_on_child_id  (child_id)
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

  # The block is what makes the link single-use. Its value is embedded when the token is minted —
  # false, because no iPad has paired yet — and compared against a fresh reading of the record
  # when the token is presented, so the first pairing stops every later presentation verifying.
  generates_token_for :invitation, expires_in: WINDOW do
    devices.any?
  end

  def revoke! = update!(revoked_at: Time.current)

  def revoked? = revoked_at.present?
end
