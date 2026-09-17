require "test_helper"

class DevicesTest < ActiveSupport::TestCase
  # 23:30 UTC on the 13th is 08:30 Tokyo on the 14th, the date the fixtures call today.
  setup { travel_to Time.utc(2026, 9, 13, 23, 30) }

  test "forgetting a child's devices signs their iPads out while their pairing links stay live" do
    out, = capture_io { Ops::Devices::Forget.call child: "Pau", confirm: true }

    assert_nil Device.find_by_token("pau-ipad-device")
    assert_nil Device.find_by_token("pau-spare-device")
    assert_not PairingLink.find_by_token("pau-first-link").revoked?
    assert_equal children(:pau), PairingLink.find_by_token("pau-first-link").devices.create!.child
    assert_equal 1, out.lines.size
    assert_includes out, "2 → 0"
  end

  test "a forgotten device keeps the row and the last-seen stamp that say which iPad it was" do
    capture_io { Ops::Devices::Forget.call child: "Pau", confirm: true }

    assert_equal Time.utc(2026, 9, 13, 23), devices(:pau_ipad).reload.last_seen_at
  end

  test "forgetting one child's devices leaves the other child's iPad signed in" do
    capture_io { Ops::Devices::Forget.call child: "Pau", confirm: true }

    assert_equal children(:teo), Device.find_by_token("teo-ipad-device").child
  end

  test "forgetting without the confirmation keyword prints the plan and changes nothing" do
    out, = capture_io { Ops::Devices::Forget.call child: "Pau" }

    assert_includes out, "plan (nothing changed, pass confirm: true)"
    assert_equal children(:pau), Device.find_by_token("pau-ipad-device").child
  end

  test "forgetting when the child has no device signed in is refused" do
    capture_io { Ops::Devices::Forget.call child: "Pau", confirm: true }

    refusal = assert_raises Ops::Base::Refused do
      capture_io { Ops::Devices::Forget.call child: "Pau", confirm: true }
    end

    assert_includes refusal.message, "Pau"
  end

  test "issuing a pairing link prints it as a scannable code beside the URL it carries" do
    out, = capture_io { Ops::Devices::IssueLink.call child: "Pau" }
    issued = out[%r{https://\S+/p/([A-Za-z0-9_-]+)}, 1]

    assert_equal 3, children(:pau).pairing_links.count
    assert_equal children(:pau), PairingLink.find_by_token(issued).child
    assert_includes out, QrCode::HALF_BLOCK
    assert_equal QrCode.render("https://study.example.com/p/#{issued}", caption: "Pau", color: children(:pau).color_hex),
      out.lines[..-2].join.chomp
    assert_includes out, "#{QrCode::FRAME.fetch(:bottom_left)}#{QrCode::FRAME.fetch(:horizontal)} Pau "
  end

  test "issuing a link against another origin prints that origin" do
    out, = capture_io { Ops::Devices::IssueLink.call child: "Teo", at: "http://192.168.1.44:3000" }

    assert_includes out, "http://192.168.1.44:3000/p/"
  end

  test "revoking a link signs out its devices while another link's devices keep working" do
    out, = capture_io { Ops::Devices::RevokeLink.call child: "Pau", issued_on: "2026-09-01", confirm: true }

    assert_nil Device.find_by_token("pau-ipad-device").child
    assert_equal children(:pau), Device.find_by_token("pau-spare-device").child
    assert_equal children(:teo), Device.find_by_token("teo-ipad-device").child
    assert_equal 1, out.lines.size
    assert_includes out, "2 → 1"
  end

  test "revoking without a date revokes every link the child still has" do
    capture_io { Ops::Devices::RevokeLink.call child: "Pau", confirm: true }

    assert_nil Device.find_by_token("pau-ipad-device").child
    assert_nil Device.find_by_token("pau-spare-device").child
    assert_equal children(:teo), Device.find_by_token("teo-ipad-device").child
  end

  test "revoking a link without the confirmation keyword prints the plan and changes nothing" do
    out, = capture_io { Ops::Devices::RevokeLink.call child: "Pau" }

    assert_includes out, "plan (nothing changed, pass confirm: true)"
    assert_equal children(:pau), Device.find_by_token("pau-ipad-device").child
  end

  test "revoking when the child has no link left is refused" do
    capture_io { Ops::Devices::RevokeLink.call child: "Pau", confirm: true }

    refusal = assert_raises Ops::Base::Refused do
      capture_io { Ops::Devices::RevokeLink.call child: "Pau", confirm: true }
    end

    assert_includes refusal.message, "Pau"
  end
end
