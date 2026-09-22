require "test_helper"

class QrCodeTest < ActiveSupport::TestCase
  PAIRING_URL = "https://study.example.com/p?token=#{"a" * 43}"
  PINK = "#e0409a"
  CELL = /\e\[[\d;]*m#{QrCode::HALF_BLOCK}/

  test "text past what a version 10 symbol holds raises rather than drawing something unreadable" do
    assert QrCode.new("a" * 271).version <= 10
    assert_raises(QrCode::TooLong) { QrCode.new "a" * 272 }
  end

  test "the rendered code carries two rows of modules a line, inside a quiet zone" do
    code = QrCode.new PAIRING_URL
    lines = code.to_text.lines

    assert_equal (code.size + 2 * QrCode::QUIET_ZONE) / 2 + 1, lines.size
    assert_equal 1, lines.map { it.scan(QrCode::HALF_BLOCK).size }.uniq.size
    assert_equal code.size + 2 * QrCode::QUIET_ZONE, lines.first.scan(QrCode::HALF_BLOCK).size
    assert lines.first.start_with?(QrCode::INK.fetch([false, false])), "the quiet zone is light"
  end

  # The default path keeps the four 4-bit escapes; only a tinted render is truecolour.
  test "a render with no color is byte-identical to the 4-bit output, escapes included" do
    plain = QrCode.new(PAIRING_URL).to_text

    assert plain.lines.first.start_with?(QrCode::INK.fetch([false, false]))
    assert_not_includes plain, "\e[38;2;"
  end

  test "a tinted render states a foreground and a background on every cell" do
    cells = module_cells QrCode.new(PAIRING_URL, caption: "Pau", color: PINK)

    assert cells.any?
    assert cells.all? { it.include?("38;2;") && it.include?("48;2;") }, "every cell names both colours"
  end

  # Counting distinct shades proves nothing: the frame's full-strength colour is a third one,
  # so the count survives finder shading collapsing into the body. Pin the positions instead.
  test "the finder patterns are drawn in the deeper shade and the body in the lighter one" do
    code = QrCode.new PAIRING_URL, caption: "Pau", color: PINK
    finder = QrCode.darken(PINK, QrCode::FINDER_FLOOR).join(";")
    body = QrCode.darken(PINK, QrCode::BODY_FLOOR).join(";")

    assert_not_equal finder, body, "the two shades must differ or this test proves nothing"
    assert_equal finder, foreground_at(code, 0, 0), "top-left finder"
    assert_equal finder, foreground_at(code, code.size - 1, 0), "top-right finder"
    assert_equal finder, foreground_at(code, 0, code.size - 1), "bottom-left finder"
    corner = (code.size - QrCode::FINDER_SIZE...code.size)
    bottom_right = corner.flat_map { |down| corner.map { foreground_at code, it, down } }

    assert_not_includes bottom_right, finder, "the bottom-right corner carries no finder pattern"
    assert_includes bottom_right, body, "and is drawn in the body shade like the rest"
  end

  # The floors are what a scanner needs; the palette has to clear them.
  # Asserting that darken's output clears the floor is true by construction -- it returns the
  # first shade that does. What is worth holding is that no palette colour needs crushing to
  # near-black to get there, which is what would quietly cost the card its hue.
  test "no palette color has to be crushed to reach the finder floor" do
    Child::COLORS.each do |name, hex|
      full, shade = QrCode.rgb(hex), QrCode.darken(hex, QrCode::FINDER_FLOOR)
      kept = shade.zip(full).reject { |_, channel| channel.zero? }.map { |a, b| a.to_f / b }.min

      assert_operator kept, :>=, 0.55, "#{name} (#{hex}) keeps only #{(kept * 100).round}% of its strength"
    end
  end

  # Bound to the bytes the renderer emits, not to the helper: body_shade could be wired to the
  # wrong constant and every assertion about darken would stay green.
  test "every dark foreground the card actually emits clears the body floor" do
    Child::COLORS.each do |name, hex|
      emitted = QrCode.new(PAIRING_URL, caption: "Pau", color: hex).to_text
        .scan(/\e\[38;2;(\d+);(\d+);(\d+)/).map { it.map(&:to_i) }.uniq
        .reject { it == QrCode::LIGHT || it == QrCode.rgb(hex) }

      assert emitted.any?, "#{name} emitted no darkened shade at all"
      emitted.each do |shade|
        ratio = QrCode.contrast shade

        assert_operator ratio, :>=, QrCode::BODY_FLOOR, "#{name} emitted #{shade.inspect} at #{ratio.round 1}:1"
      end
    end
  end

  test "a color already past a floor is returned unchanged rather than darkened needlessly" do
    purple = Child::COLORS.fetch("purple")

    assert_equal QrCode.rgb(purple), QrCode.darken(purple, QrCode::BODY_FLOOR)
  end

  test "contrast is symmetric arithmetic: white against white is 1 to 1" do
    assert_in_delta 1.0, QrCode.contrast([255, 255, 255]), 0.001
    assert_in_delta 21.0, QrCode.contrast([0, 0, 0]), 0.1
  end

  # The card: finder patterns in the deeper shade, a frame outside the quiet zone.
  test "tinting changes color and nothing else about the grid" do
    plain = QrCode.new(PAIRING_URL).modules.flatten
    tinted = QrCode.new(PAIRING_URL, caption: "Pau", color: PINK).modules.flatten
    differ = plain.zip(tinted).index { |a, b| a != b }

    assert_nil differ, "tinted render differs from the plain one at module #{differ}"
  end

  test "the frame sits outside a quiet zone that is still four modules of light ground" do
    white = "38;2;255;255;255;48;2;255;255;255"
    cells = module_cells QrCode.new(PAIRING_URL, caption: "Pau", color: PINK)

    assert_equal QrCode::QUIET_ZONE, cells.take_while { it.include? white }.size
    assert_equal QrCode::QUIET_ZONE, cells.reverse.take_while { it.include? white }.size
  end

  test "the frame closes: every line is the same printable width" do
    widths = printable_columns QrCode.new(PAIRING_URL, caption: "Pau", color: PINK)

    assert_equal 1, widths.uniq.size, "ragged frame: #{widths.uniq.inspect}"
    assert_equal QrCode.new(PAIRING_URL).size + 2 * QrCode::QUIET_ZONE + 2, widths.first
  end

  test "the child's name is set into the bottom frame edge" do
    last = QrCode.new(PAIRING_URL, caption: "Pau", color: PINK).to_text.lines.last

    assert_includes last, "Pau"
    assert_includes last, QrCode::FRAME.fetch(:bottom_right)
  end

  test "a name longer than the frame is truncated rather than breaking the border" do
    long = QrCode.new PAIRING_URL, caption: "Bartholomew" * 8, color: PINK

    assert_equal 1, printable_columns(long).uniq.size
  end

  # A terminal counts columns and String#size counts characters, so a test that measured
  # characters would agree with the bug rather than catch it.
  test "a fullwidth name keeps the frame closed, because the edge is measured in columns" do
    %w[パウ ぱうぱうぱうぱうぱうぱうぱうぱうぱうぱうぱうぱう 다니엘].each do |name|
      card = QrCode.new PAIRING_URL, caption: name, color: PINK

      assert_equal 1, printable_columns(card).uniq.size, "#{name} ragged the frame"
    end
  end

  test "every frame cell carries both a foreground and a background" do
    top = QrCode.new(PAIRING_URL, caption: "Pau", color: PINK).to_text.lines.first

    assert_includes top, "38;2;224;64;154"
    assert_includes top, "48;2;255;255;255"
  end

  test "the frame needs both a color and a name; either alone falls back to today's output" do
    plain = QrCode.new(PAIRING_URL).to_text

    assert_equal plain, QrCode.new(PAIRING_URL, color: PINK).to_text
    assert_not_includes QrCode.new(PAIRING_URL, caption: "Pau").to_text, QrCode::FRAME.fetch(:top_left)
  end

  test "a caption with no color still prints its own line, and no caption adds no line" do
    assert_includes QrCode.new(PAIRING_URL, caption: "Pau").to_text.lines.last, "Pau"
    assert_equal QrCode.new(PAIRING_URL).to_text, QrCode.new(PAIRING_URL, caption: "").to_text
  end

  test "the framed card prints the name once, not twice" do
    assert_equal 1, QrCode.new(PAIRING_URL, caption: "Pau", color: PINK).to_text.scan("Pau").size
  end

  private

  def printable_columns(code)
    code.to_text.lines.map { QrCode.columns it.gsub(/\e\[[\d;]*m/, "").chomp }
  end

  # The foreground of the cell holding one module, addressed in code coordinates. Two module
  # rows share a text line, so the row picks the line and its parity picks fg or bg.
  def foreground_at(code, across, down)
    line = code.to_text.lines[(down + QrCode::QUIET_ZONE) / 2 + 1]
    cell = line.scan(/\e\[38;2;(\d+;\d+;\d+);48;2;(\d+;\d+;\d+)m/)[across + QrCode::QUIET_ZONE + 1]

    ((down + QrCode::QUIET_ZONE).even? ? cell.first : cell.last)
  end

  # The module cells of the first line that reaches the code itself, with the frame's own cell
  # at each end dropped. The lines above it are quiet zone all the way across.
  def module_cells(code)
    white = "38;2;255;255;255;48;2;255;255;255"
    code.to_text.lines
      .map { it.scan(CELL) }
      .find { it.any? && it.any? { |cell| !cell.include?(white) } }
  end
end
