require "rqrcode_core"

# A pairing URL, drawn as a QR code in the terminal that issued it. rqrcode_core does the
# encoding; what is here is the drawing, which is the part no library does the way a console
# needs it — see HALF_BLOCK below.
class QrCode
  class TooLong < StandardError; end

  # Error correction level L. Redundancy buys little here — the code is read off a screen held
  # up to a camera, not off paper that can tear — so the capacity is worth more. Version 6 is
  # the largest a pairing URL needs, and the cap is what keeps a mistyped origin from drawing a
  # symbol taller than the window it is printed into.
  LEVEL = :l
  MODE = :byte_8bit
  MAX_VERSION = 6

  # The foreground of a character cell is the top half and the background the bottom half,
  # so one line of text carries two rows of modules and each module comes out square. A
  # version 6 code is 25 lines this way and 49 a row at a time, which is why the renderer is
  # still ours. Both colors are stated on every cell: a terminal with a dark theme would
  # otherwise render the code inverted, which many cameras will not read.
  HALF_BLOCK = "▀"
  INK = {
    [true, true] => "\e[30;40m",
    [true, false] => "\e[30;107m",
    [false, true] => "\e[97;40m",
    [false, false] => "\e[97;107m"
  }.freeze
  RESET = "\e[0m"
  QUIET_ZONE = 4

  # A scanner finds a code by the luminance between its dark and light modules, not by hue, so
  # the child's color is the code's hue and these are its luminance. 4.5:1 is the body, above
  # the 4:1 a scanner needs; 7:1 is the three finder patterns. The deeper shade on the finders
  # is decoration, not protection: both shades land far below any plausible binarisation
  # threshold, so the gap is what makes the card look designed, and nothing more.
  # Blue, purple and red already clear the body floor, so for those three the frame and the
  # body are the same color; only the four that need darkening keep full strength for the frame.
  BODY_FLOOR = 4.5
  FINDER_FLOOR = 7.0
  LIGHT = [255, 255, 255].freeze
  FINDER_SIZE = 7

  # Outside the quiet zone, so none of it is anything a camera measures.
  FRAME = {
    top_left: "╭", top_right: "╮", bottom_left: "╰", bottom_right: "╯",
    horizontal: "─", vertical: "│"
  }.freeze

  CAPTION_MARK = "█"
  CAPTION_INK = "\e[107;30m"

  class << self
    def render(text, caption: nil, color: nil) = new(text, caption:, color:).to_text

    def rgb(hex) = hex.delete("#").scan(/../).map { it.to_i 16 }

    # WCAG relative luminance, against the white ground this renderer paints itself.
    def contrast(rgb)
      channels = rgb.map do |channel|
        value = channel / 255.0
        (value <= 0.03928) ? value / 12.92 : ((value + 0.055) / 1.055)**2.4
      end
      luminance = 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]

      1.05 / (luminance + 0.05)
    end

    # Scaling all three channels by one factor is what keeps the hue: the ordering between them
    # never changes, so a pink darkens to a darker pink. Whether it still reads as pink once it
    # reaches the finder floor is a judgement no assertion makes; it was checked by eye.
    def darken(hex, floor)
      channels = rgb(hex)
      return channels if contrast(channels) >= floor

      100.downto(1) do |percent|
        candidate = channels.map { (it * percent / 100.0).round }
        return candidate if contrast(candidate) >= floor
      end

      raise ArgumentError, "no shade of #{hex} reaches #{floor}:1; the ceiling is 21:1 against white"
    end

    # A terminal counts columns, not characters, and String#size counts characters. A fullwidth
    # name would push the frame's bottom edge wider than the rest of it.
    WIDE = /[\u1100-\u115F\u2E80-\uA4CF\uA960-\uA97F\uAC00-\uD7A3\uF900-\uFAFF\uFE10-\uFE19\uFE30-\uFE6F\uFF00-\uFF60\uFFE0-\uFFE6]|[\u{1F300}-\u{1FAFF}]|[\u{20000}-\u{3FFFD}]/

    def columns(text) = text.each_char.sum { column_width it }

    # Truncates on column width, so a fullwidth name is cut where it actually stops fitting.
    def clamp(text, budget)
      text.each_char.each_with_object(+"") do |char, kept|
        budget -= column_width char
        break kept if budget < 0
        kept << char
      end
    end

    private

    def column_width(char)
      return 0 if char.match?(/[\p{Mn}\p{Me}]/)

      char.match?(WIDE) ? 2 : 1
    end
  end

  def initialize(text, caption: nil, color: nil)
    @caption, @color = caption, color
    @code = RQRCodeCore::QRCode.new text.to_s, level: LEVEL, mode: MODE, max_size: MAX_VERSION
  rescue RQRCodeCore::QRCodeRunTimeError
    raise TooLong, "#{text.to_s.bytesize} bytes is more than a version #{MAX_VERSION} code holds"
  end

  def modules = @code.modules

  def size = modules.size

  def version = @code.version

  def to_text
    card = evened(padded).each_slice(2).map { |top, bottom| line top, bottom }

    card? ? frame(card) : [*card, *caption_line].join("\n")
  end

  private

  # Tinting and framing are one question, not two that happen to agree: the card is the color,
  # the frame and the name together. A color with no name is not a card, so it renders today's
  # black-on-white code rather than a tinted one nothing identifies; a name with no color keeps
  # its caption line under a plain code.
  def card? = @color.present? && @caption.present?

  # The full printable width of the card: the code plus the quiet zone on both sides.
  def width = size + 2 * QUIET_ZONE

  def body_shade = @_body_shade ||= self.class.darken(@color, BODY_FLOOR)

  def finder_shade = @_finder_shade ||= self.class.darken(@color, FINDER_FLOOR)

  # Each cell is the color its module is drawn in, or nil for the light ground. The quiet zone
  # is nil all the way round, which is what keeps it four modules of light whatever the tint.
  def padded
    margin = Array.new QUIET_ZONE
    quiet = Array.new width

    Array.new(QUIET_ZONE) { quiet } + shaded.map { margin + it + margin } + Array.new(QUIET_ZONE) { quiet }
  end

  # One text line carries two module rows, so an odd count would leave the last one unpaired.
  def evened(rows) = rows.size.odd? ? rows + [Array.new(width)] : rows

  def shaded
    modules.each_with_index.map do |row, down|
      row.each_with_index.map do |dark, across|
        next unless dark
        next :dark unless card?

        finder?(across, down) ? finder_shade : body_shade
      end
    end
  end

  # The three 7x7 blocks the specification fixes at the top-left, top-right and bottom-left
  # corners of every version. rqrcode_core does not say which modules are function patterns,
  # and it does not have to: these positions are the same for every code it can produce.
  def finder?(across, down)
    near_across, near_down = across < FINDER_SIZE, down < FINDER_SIZE
    far_across, far_down = across >= size - FINDER_SIZE, down >= size - FINDER_SIZE

    near_across && near_down || far_across && near_down || near_across && far_down
  end

  def line(top, bottom)
    top.zip(bottom).map { |above, below| "#{ink above, below}#{HALF_BLOCK}" }.join + RESET
  end

  def ink(top, bottom)
    return INK.fetch([!top.nil?, !bottom.nil?]) unless card?

    escape top, bottom
  end

  # Both halves are always stated, which is the whole point: a cell that names only one leaves
  # the other to the terminal's own theme, and a dark theme renders the code inverted.
  def escape(foreground, background = LIGHT)
    "\e[38;2;#{(foreground || LIGHT).join(";")};48;2;#{(background || LIGHT).join(";")}m"
  end

  def frame(card)
    edge = FRAME.fetch(:horizontal)
    name = self.class.clamp @caption.to_s, width - 4
    bottom = "#{edge} #{name} " + edge * (width - self.class.columns("#{edge} #{name} "))

    [
      rule(FRAME.fetch(:top_left) + edge * width + FRAME.fetch(:top_right)),
      *card.map { "#{rule FRAME.fetch(:vertical)}#{it}#{rule FRAME.fetch(:vertical)}" },
      rule(FRAME.fetch(:bottom_left) + bottom + FRAME.fetch(:bottom_right))
    ].join("\n")
  end

  # The frame states both colors for the same reason every module cell does: left to the
  # terminal's own background, it would put a dark ground immediately outside the quiet zone.
  def rule(text) = "#{escape color_rgb}#{text}#{RESET}"

  def color_rgb = @_color_rgb ||= self.class.rgb(@color)

  def caption_line
    return if @caption.blank?

    name = self.class.clamp @caption.to_s, width - QUIET_ZONE - 2
    trailing = " " * (width - QUIET_ZONE - 2 - self.class.columns(name))

    "#{CAPTION_INK}#{" " * QUIET_ZONE}#{CAPTION_MARK} #{name}#{trailing}#{RESET}"
  end
end
