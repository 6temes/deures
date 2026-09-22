# == Schema Information
#
# Table name: devices
#
#  id           :integer          not null, primary key
#  forgotten_at :datetime
#  last_seen_at :datetime
#  token_digest :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  child_id     :integer          not null
#
# Indexes
#
#  index_devices_on_child_id      (child_id)
#  index_devices_on_token_digest  (token_digest) UNIQUE
#
# Foreign Keys
#
#  child_id  (child_id => children.id)
#
class Device < ApplicationRecord
  belongs_to :child

  include Tokenized

  # A forgotten device answers to no token, so the cookie resolves to nothing and the iPad has no
  # identity until a fresh link is opened on it. The filtering has to happen at the lookup: anywhere
  # later and Current.device holds the forgotten row, which is all a paired-or-not check needs
  # to see to treat the iPad as already paired and never re-pair it.
  def self.find_by_token(token)
    device = super
    device unless device&.forgotten?
  end

  # Stamped rather than destroyed: the last-seen stamp is the only record of which iPad this was.
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
