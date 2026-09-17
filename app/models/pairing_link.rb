# == Schema Information
#
# Table name: pairing_links
#
#  id           :integer          not null, primary key
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
  belongs_to :child

  has_many :devices, dependent: :destroy

  include Tokenized

  def revoke!
    update! revoked_at: Time.current
  end

  def revoked?
    revoked_at.present?
  end
end
