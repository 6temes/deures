require "test_helper"

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
class PairingLinkTest < ActiveSupport::TestCase
  test "issues a plaintext token once and stores only its digest" do
    link = children(:pau).pairing_links.create!

    assert_equal Digest::SHA256.hexdigest(link.plain_token), link.token_digest
    assert_not_includes link.attributes.values.map(&:to_s), link.plain_token
    assert_nil PairingLink.find(link.id).plain_token
  end

  test "finds a link by its plaintext token" do
    link = children(:pau).pairing_links.create!

    assert_equal link, PairingLink.find_by_token(link.plain_token)
  end

  test "an unknown or malformed token finds no link rather than raising" do
    children(:pau).pairing_links.create!

    assert_nil PairingLink.find_by_token("not-a-token")
    assert_nil PairingLink.find_by_token("")
    assert_nil PairingLink.find_by_token(nil)
  end

  test "issuing a second link for a child leaves the first link's devices working" do
    first = children(:pau).pairing_links.create!
    device = first.devices.create!

    children(:pau).pairing_links.create!

    assert_equal children(:pau), Device.find_by_token(device.plain_token).child
  end

  test "revoking a link leaves it findable but signs its devices out" do
    link = children(:pau).pairing_links.create!
    device = link.devices.create!

    link.revoke!

    assert_predicate link, :revoked?
    assert_equal link, PairingLink.find_by_token(link.plain_token)
    assert_nil Device.find_by_token(device.plain_token).child
  end
end
