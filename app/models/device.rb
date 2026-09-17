# == Schema Information
#
# Table name: devices
#
#  id              :integer          not null, primary key
#  forgotten_at    :datetime
#  last_seen_at    :datetime
#  token_digest    :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  pairing_link_id :integer          not null
#
# Indexes
#
#  index_devices_on_pairing_link_id  (pairing_link_id)
#  index_devices_on_token_digest     (token_digest) UNIQUE
#
# Foreign Keys
#
#  pairing_link_id  (pairing_link_id => pairing_links.id)
#
class Device < ApplicationRecord
  belongs_to :pairing_link

  include Tokenized

  # A forgotten device answers to no token, so the cookie resolves to nothing and the installed
  # icon's start URL pairs the iPad again. The same check inside #child, beside the revoked one,
  # would instead leave the forgotten row in Current.device, which is all the pairing controller
  # needs to treat the iPad as already paired and never re-pair it.
  def self.find_by_token(token)
    device = super
    device unless device&.forgotten?
  end

  def child
    pairing_link.child unless pairing_link.revoked?
  end

  # Stamped rather than destroyed: the last-seen stamp is the only record of which iPad this was.
  # Revoking the link it paired through as well would take the child's Home Screen icon with it.
  def forget!
    update! forgotten_at: Time.current
  end

  def forgotten?
    forgotten_at.present?
  end

  def touch_last_seen
    return if last_seen_at && last_seen_at > 1.hour.ago

    update_column :last_seen_at, Time.current
  end
end
