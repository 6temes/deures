module Ops
  # Operations name a child, a deck, and a card the way the household does rather than by id,
  # so a refusal has to hand back the names that would have worked.
  module Lookups
    private

    def child!(name)
      Child.find_by(name:) ||
        refuse!(%(no child called "#{name}" — the children are: #{Child.order(:name).pluck(:name).join(", ")}))
    end

    def deck!(name)
      Deck.find_by(name:) ||
        refuse!(%(no deck called "#{name}" — the decks are: #{Deck.order(:name).pluck(:name).join(", ")}))
    end

    # A retired card and the card that replaced it can hold the same prompt in one deck, so
    # the live one is the one a name resolves to wherever there is a choice.
    def card!(deck:, prompt:)
      found = deck! deck
      key = Normalize.prompt prompt

      found.cards.find_by(prompt_key: key, retired_at: nil) || found.cards.find_by(prompt_key: key) ||
        refuse!(%(no card "#{prompt}" in #{found.name} — add it first))
    end
  end
end
