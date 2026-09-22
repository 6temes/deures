# == Schema Information
#
# Table name: pairing_links
#
#  id         :integer          not null, primary key
#  claimed_at :datetime
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

  # The block is what makes the link single-use. Its value is embedded when the token is minted —
  # false, because no iPad has paired yet — and compared against a fresh reading of the record
  # when the token is presented, so the first pairing stops every later presentation verifying.
  generates_token_for :invitation, expires_in: WINDOW do
    claimed_at?
  end

  # The link's whole job, done once: the iPad that opens it gets a device of the child's own,
  # and the stamp the token's block reads is what stops a second iPad following it through.
  # One transaction: a stamp without the device it stands for would spend the token and leave the
  # child unable to pair until someone at a console noticed and issued another link.
  def claim!
    transaction do
      update! claimed_at: Time.current
      child.devices.create!
    end
  end
end
