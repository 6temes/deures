require "test_helper"

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
class PairingLinkTest < ActiveSupport::TestCase
  test "finds a link by a token minted for it" do
    link = children(:pau).pairing_links.create!

    assert_equal link, PairingLink.find_by_token_for(:invitation, link.generate_token_for(:invitation))
  end

  test "a token stops verifying once an iPad has paired through the link" do
    link = children(:pau).pairing_links.create!
    token = link.generate_token_for(:invitation)

    link.claim!

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

  test "claiming a link hands the child a device and is what spends the link" do
    link = children(:pau).pairing_links.create!

    device = link.claim!

    assert_equal children(:pau), device.child
    assert_predicate link.reload, :claimed_at?
  end

  test "the iPad a link paired keeps working once a second link is issued for the child" do
    device = children(:pau).pairing_links.create!.claim!

    children(:pau).pairing_links.create!

    assert_equal children(:pau), Device.find_by_token(device.plain_token).child
  end
end
