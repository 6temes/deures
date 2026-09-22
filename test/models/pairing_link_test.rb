require "test_helper"

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
class PairingLinkTest < ActiveSupport::TestCase
  test "finds a link by a token minted for it" do
    link = children(:pau).pairing_links.create!

    assert_equal link, PairingLink.find_by_token_for(:invitation, link.generate_token_for(:invitation))
  end

  test "a token stops verifying once an iPad has paired through the link" do
    link = children(:pau).pairing_links.create!
    token = link.generate_token_for(:invitation)

    link.devices.create!

    assert_nil PairingLink.find_by_token_for(:invitation, token)
  end

  test "a token past the window finds no link" do
    link = children(:pau).pairing_links.create!
    token = link.generate_token_for(:invitation)

    travel PairingLink::WINDOW + 1.second

    assert_nil PairingLink.find_by_token_for(:invitation, token)
  end

  test "a forged, truncated or absent token finds no link rather than raising" do
    link = children(:pau).pairing_links.create!
    token = link.generate_token_for(:invitation)

    assert_nil PairingLink.find_by_token_for(:invitation, "not-a-token")
    assert_nil PairingLink.find_by_token_for(:invitation, token[0..-5])
    assert_nil PairingLink.find_by_token_for(:invitation, "")
    assert_nil PairingLink.find_by_token_for(:invitation, nil)
  end

  test "one child's token does not resolve to another child's link" do
    token = children(:pau).pairing_links.create!.generate_token_for(:invitation)

    assert_equal children(:pau), PairingLink.find_by_token_for(:invitation, token).child
  end

  test "issuing a second link for a child leaves the first link's devices working" do
    first = children(:pau).pairing_links.create!
    device = first.devices.create!

    children(:pau).pairing_links.create!

    assert_equal children(:pau), Device.find_by_token(device.plain_token).child
  end

  test "revoking a link signs its devices out while the token it minted stays spent" do
    link = children(:pau).pairing_links.create!
    device = link.devices.create!

    link.revoke!

    assert_predicate link, :revoked?
    assert_nil Device.find_by_token(device.plain_token).child
  end

  test "revoking a link that no iPad has used leaves its token verifying, for the controller to refuse" do
    link = children(:pau).pairing_links.create!
    token = link.generate_token_for(:invitation)

    link.revoke!

    assert_equal link, PairingLink.find_by_token_for(:invitation, token)
    assert_predicate PairingLink.find_by_token_for(:invitation, token), :revoked?
  end
end
