require "test_helper"

class ChildrenTest < ActiveSupport::TestCase
  # 23:30 UTC on the 13th is 08:30 Tokyo on the 14th, the date the fixtures call today.
  setup { travel_to Time.utc(2026, 9, 13, 23, 30) }

  test "creating a child takes the household's date and the default pace" do
    out, = capture_io { Ops::Children::Create.call name: "Mar", color: "pink" }
    child = Child.find_by! name: "Mar"

    assert_equal Date.new(2026, 9, 14), child.created_on
    assert_equal "pink", child.color
    assert_equal [10, 5], [child.light_day_threshold, child.new_card_cap]
    assert_equal 1, out.lines.size
    assert_includes out, "children 2 → 3"
  end

  test "a color outside the palette is refused, and the refusal prints the names that would work" do
    refusal = assert_raises Ops::Base::Refused do
      capture_io { Ops::Children::Create.call name: "Mar", color: "mauve" }
    end

    assert_includes refusal.message, "mauve"
    assert_includes refusal.message, Child::COLORS.keys.join(", ")
    assert_not Child.exists?(name: "Mar")
  end

  test "a name another child already answers to is refused" do
    refusal = assert_raises Ops::Base::Refused do
      capture_io { Ops::Children::Create.call name: "Pau", color: "red" }
    end

    assert_includes refusal.message, "Pau"
    assert_equal 2, Child.count
  end

  test "setting the threshold and the cap prints the before and the after" do
    out, = capture_io { Ops::Children::SetPace.call child: "Teo", threshold: 12, cap: 3 }
    teo = children(:teo).reload

    assert_equal "Teo: threshold 10, cap 3 → threshold 12, cap 3\n", out
    assert_equal [12, 3], [teo.light_day_threshold, teo.new_card_cap]
  end

  test "setting one of the two leaves the other where it was" do
    capture_io { Ops::Children::SetPace.call child: "Pau", cap: 2 }
    pau = children(:pau).reload

    assert_equal [10, 2], [pau.light_day_threshold, pau.new_card_cap]
  end

  test "setting a cap above the threshold is refused" do
    refusal = assert_raises Ops::Base::Refused do
      capture_io { Ops::Children::SetPace.call child: "Pau", cap: 11 }
    end

    assert_includes refusal.message, "11"
    assert_equal 5, children(:pau).reload.new_card_cap
  end

  test "setting a threshold below one is refused" do
    refusal = assert_raises Ops::Base::Refused do
      capture_io { Ops::Children::SetPace.call child: "Pau", threshold: 0 }
    end

    assert_includes refusal.message, "0"
    assert_equal 10, children(:pau).reload.light_day_threshold
  end

  test "an operation naming a child nobody is called is refused, and the refusal lists the children" do
    refusal = assert_raises Ops::Base::Refused do
      capture_io { Ops::Children::SetPace.call child: "Mar", cap: 1 }
    end

    assert_includes refusal.message, "Pau, Teo"
  end
end
