require "digest"

# Turns what a child typed, and what the agent authored, into the strings we compare.
#
# Two normalizers, deliberately different: an answer keeps its internal spacing (there is
# none — the pad types digits) while a prompt loses every space, so re-spacing "23 + 19"
# as "23+19" is the same question and keeps every child's progress.
module Normalize
  UNIT = "\x1f".freeze
  RECORD = "\x1e".freeze

  class << self
    def answer(raw)
      base(raw).strip.sub(/\A0+(?=\d)/, "")
    end

    def prompt(raw)
      base(raw).gsub(/[[:space:]]/, "")
    end

    # A card's meaning: its question plus the set of answers it accepts. Sorting means
    # reordering the accepted answers does not reset anyone, even though it changes
    # which one a wrong answer displays.
    def digest(prompt_key, accepted_keys)
      Digest::SHA256.hexdigest([prompt_key, accepted_keys.uniq.sort.join(RECORD)].join(UNIT))
    end

    private

    # NFKC is what folds full-width digits, and it has to run before the strip or a
    # Japanese keyboard's full-width space survives it. scrub first, because the string
    # arrives over HTTP from a device we do not control and unicode_normalize raises on
    # malformed UTF-8.
    def base(raw)
      raw.to_s.dup.force_encoding(Encoding::UTF_8).scrub("").unicode_normalize(:nfkc).downcase(:fold)
    end
  end
end
