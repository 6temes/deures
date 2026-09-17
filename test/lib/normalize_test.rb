require "test_helper"

class NormalizeTest < ActiveSupport::TestCase
  # AE8: what a child may type and still be right.
  test "folds full-width digits to half-width" do
    assert_equal "65", Normalize.answer("６５")
  end

  test "drops leading zeros" do
    assert_equal "65", Normalize.answer("065")
  end

  test "does not fold a wrong answer into a right one" do
    assert_equal "655", Normalize.answer("655")
  end

  test "keeps the last digit when the answer is all zeros" do
    assert_equal "0", Normalize.answer("0")
    assert_equal "0", Normalize.answer("00")
    assert_equal "0", Normalize.answer("000")
  end

  # NFKC has to run before the strip, or a Japanese keyboard's full-width space survives it.
  test "strips a full-width space around an answer" do
    assert_equal "65", Normalize.answer("　６５　")
  end

  test "normalizes invalid UTF-8 instead of raising" do
    assert_equal "65", Normalize.answer("\xff65".b)
  end

  test "case-folds text answers" do
    assert_equal "ab c", Normalize.answer("ＡB c")
  end

  test "is idempotent" do
    %w[６５ 065 00 655].each do |raw|
      once = Normalize.answer(raw)
      assert_equal once, Normalize.answer(once), "not idempotent for #{raw.inspect}"
    end
  end

  test "treats a blank answer as empty" do
    assert_equal "", Normalize.answer("")
    assert_equal "", Normalize.answer("   ")
    assert_equal "", Normalize.answer(nil)
  end

  # AE11: a spacing edit is the same question; a different sum is not.
  test "prompt normalization removes every space, not just the ends" do
    assert_equal Normalize.prompt("23 + 19"), Normalize.prompt("23+19")
    assert_equal "23+19", Normalize.prompt("  23 + 19 ")
  end

  test "prompt normalization keeps different questions different" do
    assert_not_equal Normalize.prompt("23 + 19"), Normalize.prompt("27 + 15")
  end

  test "digest is unchanged by a spacing-only prompt edit" do
    before = Normalize.digest(Normalize.prompt("23 + 19"), [Normalize.answer("42")])
    after = Normalize.digest(Normalize.prompt("23+19"), [Normalize.answer("42")])
    assert_equal before, after
  end

  test "digest changes when the question changes even though the answer does not" do
    before = Normalize.digest(Normalize.prompt("23 + 19"), [Normalize.answer("42")])
    after = Normalize.digest(Normalize.prompt("27 + 15"), [Normalize.answer("42")])
    assert_not_equal before, after
  end

  test "digest is unchanged by reordering the accepted answers" do
    before = Normalize.digest("high", %w[high tall])
    after = Normalize.digest("high", %w[tall high])
    assert_equal before, after
  end

  test "digest is unchanged by a duplicate accepted answer" do
    assert_equal Normalize.digest("high", %w[high]), Normalize.digest("high", %w[high high])
  end
end
