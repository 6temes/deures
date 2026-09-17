module Ops
  # The questions themselves: writing them, correcting them, and taking them out of
  # circulation without losing what the children did with them.
  module Cards
    # Everything the pad can type, and so everything a card is allowed to accept.
    ANSWER = /\A[0-9]{1,6}\z/

    # The checks the card operations share.
    class Base < Ops::Base
      include Lookups

      private

      # Ops::Decks::Unassign leaves a child's progress rows behind when it takes the deck
      # off them, so a count over every row on the card would report children the change
      # cannot reach.
      def assigned_progresses(card)
        card.card_progresses.where child_id: DeckAssignment.assigned.where(deck_id: card.deck_id).select(:child_id)
      end

      # Card's own validations refuse a duplicate prompt and an empty answer list too, but
      # a raised RecordInvalid leaves the agent with a stack trace instead of a sentence.
      def check_content!(deck:, prompt:, answers:, except: nil)
        refuse! %("#{prompt}" has no accepted answer) if answers.empty?

        typeable = answers.reject { Normalize.answer(it).match? ANSWER }
        refuse! %("#{prompt}" accepts #{typeable.join(", ")} — the pad types one to six digits and nothing else) if typeable.any?

        live = deck.cards.where(retired_at: nil)
        live = live.where.not(id: except) if except
        refuse! %("#{prompt}" is already in #{deck.name} — update that card or retire it first) if live.exists?(prompt_key: prompt)
      end

      def remove_from_open_queues(card)
        StudyDay.open_today.count { it.remove_card! card }
      end
    end

    class Add < Base
      PLACES = %w[end front].freeze

      operation name: "cards.add",
        description: "Add cards to the end or the front of a deck, optionally due today.",
        example: %(Ops::Cards::Add.call deck: "Addition to 100", cards: { "9 + 9" => "18" }, confirm: true),
        confirm: true

      def initialize(deck:, cards:, at: "end", due_today: false)
        @deck_name, @cards, @at, @due_today = deck, cards, at.to_s, due_today
      end

      def perform
        refuse! %(at: takes "#{PLACES.join('" or "')}") unless PLACES.include?(@at)

        deck = deck! @deck_name
        before = deck.cards.count
        added = write deck
        progresses = CardProgress.where(card_id: added.map(&:id)).to_a
        progresses.each { it.update! due_on: Date.current } if @due_today
        children = progresses.map(&:child_id).uniq.size

        %(#{deck.name}: cards #{before} → #{deck.cards.count}, #{added.size} added at the #{@at}, ) +
          %(#{@due_today ? "due today" : "new"} for #{children} #{"child".pluralize(children)})
      end

      private

      # Card by card rather than in one pass, because a prompt repeated inside the batch is
      # a duplicate of the same kind as one already in the deck and has to refuse the same way.
      def write(deck)
        places(deck).zip(@cards.to_a).map do |position, (prompt, answers)|
          answers = Array(answers)
          check_content!(deck:, prompt:, answers:)
          deck.cards.create! position:, prompt:, accepted_answers: answers
        end
      end

      # A card's position is its place in the order the child meets the deck in, so adding to
      # the front moves every card already there down.
      def places(deck)
        return (deck.cards.maximum(:position).to_i + 1..).take(@cards.size) unless @at == "front"

        deck.cards.order(:position).each { it.update! position: it.position + @cards.size }
        (1..@cards.size).to_a
      end
    end

    class Delete < Base
      operation name: "cards.delete",
        description: "Delete a card no child has ever attempted.",
        example: %(Ops::Cards::Delete.call deck: "Times tables", prompt: "6 × 7")

      def initialize(deck:, prompt:)
        @deck_name, @prompt = deck, prompt
      end

      def perform
        card = card! deck: @deck_name, prompt: @prompt
        deck = card.deck
        refuse! %("#{card.prompt}" has been attempted — retire it instead, which keeps the attempts and every child's progress) if card.attempts.exists?

        before = deck.cards.count
        # The day has to be settled while the item still names the card: dependent: :nullify
        # empties the card out of the item without clearing it, and a removal is the only
        # thing that settles the day it empties.
        left = remove_from_open_queues card
        card.destroy!

        %(#{deck.name}: cards #{before} → #{deck.cards.count}, "#{card.prompt}" deleted, out of #{left} open #{"queue".pluralize(left)})
      end
    end

    class Retire < Base
      operation name: "cards.retire",
        description: "Retire a card, keeping every child's progress and attempts.",
        example: %(Ops::Cards::Retire.call deck: "Addition to 100", prompt: "7 - 7")

      def initialize(deck:, prompt:)
        @deck_name, @prompt = deck, prompt
      end

      def perform
        card = card! deck: @deck_name, prompt: @prompt
        deck = card.deck
        refuse! %("#{card.prompt}" is already retired) if card.retired?

        card.update! retired_at: Time.current
        left = remove_from_open_queues card

        %("#{card.prompt}" in #{deck.name}: live → retired, out of #{left} open #{"queue".pluralize(left)}, progress kept)
      end
    end

    class Unretire < Base
      # The example resumes the card the retire example above it retires: the test that runs
      # every registered example runs them in name order, so a different card here would
      # arrive with nothing retired to resume.
      operation name: "cards.unretire",
        description: "Put a retired card back, resuming each child's due date.",
        example: %(Ops::Cards::Unretire.call deck: "Addition to 100", prompt: "7 - 7")

      def initialize(deck:, prompt:)
        @deck_name, @prompt = deck, prompt
      end

      def perform
        deck = deck! @deck_name
        card = find_retired_card! deck, @prompt
        refuse! %("#{card.prompt}" is in #{deck.name} again as a live card — update that one instead) if deck.cards.where(retired_at: nil).exists?(prompt_key: card.prompt_key)

        card.update! retired_at: nil
        resumed = assigned_progresses(card).where.not(due_on: nil).count
        unseen = assigned_progresses(card).where(due_on: nil).count

        %("#{card.prompt}" in #{deck.name}: retired → live, due again for #{resumed} #{"child".pluralize(resumed)}, ) +
          %(new for #{unseen} #{"child".pluralize(unseen)})
      end

      private

      def find_retired_card!(deck, prompt)
        card = deck.cards.where.not(retired_at: nil).find_by prompt_key: prompt
        refuse! %(no retired card "#{prompt}" in #{deck.name}) unless card
        card
      end
    end

    class Update < Base
      operation name: "cards.update",
        description: "Change a card's prompt or its accepted answers; a changed question resets progress.",
        example: %(Ops::Cards::Update.call deck: "Addition to 100", prompt: "23 + 19", to: "23+19")

      def initialize(deck:, prompt:, to: nil, answers: nil)
        @deck_name, @prompt, @to, @answers = deck, prompt, to, answers
      end

      def perform
        refuse! "nothing to change — pass to: for a new prompt, answers: for new accepted answers" if @to.nil? && @answers.nil?

        card = card! deck: @deck_name, prompt: @prompt
        deck = card.deck
        prompt, answers = @to || card.prompt, @answers ? Array(@answers) : card.accepted_answers
        check_content! deck:, prompt:, answers:, except: card

        was, meant = "#{card.prompt} = #{card.accepted_answers.join(" / ")}", card.content_digest
        card.update! prompt:, accepted_answers: answers
        changed = card.content_digest != meant
        reset = changed ? reset_progress(card) : 0

        %("#{was}" → "#{card.prompt} = #{card.accepted_answers.join(" / ")}" in #{deck.name}: ) +
          (changed ? "a different question now, #{reset} #{"child".pluralize(reset)} reset to new" : "same question, progress kept")
      end

      private

      # Nobody's interval means anything once the question changes, so every child holding
      # progress on it meets the card again as one they have never seen. The children the
      # summary reports are the ones still studying the deck, who are the ones that meet it.
      def reset_progress(card)
        card.card_progresses.to_a.each { it.update! due_on: nil, last_answered_on: nil, parked_on: nil, rung: 0 }
        # And out of every open queue, because the item there froze the accepted answers as
        # they were rendered. A child answering the corrected question would be graded
        # against the answer the correction replaced, and climb the progress just reset.
        remove_from_open_queues card
        assigned_progresses(card).count
      end
    end
  end
end
