module Ops
  # Decks, and which child studies which of them.
  module Decks
    class Create < Ops::Base
      operation name: "decks.create",
        description: "Create an empty deck.",
        example: %(Ops::Decks::Create.call name: "Subtraction to 100")

      def initialize(name:)
        @name = name
      end

      def perform
        before = Deck.count
        deck = Deck.create! name: @name

        %(decks #{before} → #{Deck.count}, "#{deck.name}" created empty)
      end
    end

    # The two operations that put a deck on a child or take it back off. Both name the pair
    # the way the agent thinks of it, by the child's name and the deck's.
    class Base < Ops::Base
      include Lookups

      def initialize(child:, deck:)
        @child_name, @deck_name = child, deck
      end
    end

    class Assign < Base
      operation name: "decks.assign",
        description: "Assign a deck to a child, resuming every due date they kept.",
        example: %(Ops::Decks::Assign.call child: "Teo", deck: "Times tables", confirm: true),
        confirm: true

      def perform
        child, deck = child!(@child_name), deck!(@deck_name)
        assignment = child.deck_assignments.find_by(deck:)
        refuse! %(#{child.name} already studies "#{deck.name}") if assignment&.assigned?

        before = child.deck_assignments.assigned.count
        assign child, deck, assignment
        live = deck.cards.where(retired_at: nil)
        cards = live.count
        # A retired card never reaches the child, so a due date kept on one is not a due date
        # this assignment resumes.
        resumed = child.card_progresses.where(card_id: live.select(:id)).where.not(due_on: nil).count

        %(#{child.name}: decks #{before} → #{before + 1}, "#{deck.name}" assigned with #{cards} #{"card".pluralize(cards)}, ) +
          %(#{resumed} due #{"date".pluralize(resumed)} resumed)
      end

      private

      # Re-assigning is the same row coming back rather than a new one, which is what leaves
      # the child's progress on the deck's cards where it was.
      def assign(child, deck, assignment)
        return assignment.update!(unassigned_at: nil) if assignment

        child.deck_assignments.create! deck:, position: child.deck_assignments.maximum(:position).to_i + 1
      end
    end

    class Unassign < Base
      operation name: "decks.unassign",
        description: "Take a deck off a child, keeping their progress and attempts.",
        example: %(Ops::Decks::Unassign.call child: "Pau", deck: "Times tables", confirm: true),
        confirm: true

      def perform
        child, deck = child!(@child_name), deck!(@deck_name)
        assignment = child.deck_assignments.assigned.find_by(deck:)
        refuse! %(#{child.name} does not study "#{deck.name}") unless assignment

        before = child.deck_assignments.assigned.count
        assignment.update! unassigned_at: Time.current
        left = remove_from_open_queue child, deck

        %(#{child.name}: decks #{before} → #{before - 1}, "#{deck.name}" unassigned, #{left} out of today's queue, progress kept)
      end

      private

      # The day's queue only ever shrinks once it is open, and taking the child's last card
      # out of it is what records the day as done.
      def remove_from_open_queue(child, deck)
        day = child.study_days.open_today.first
        return 0 unless day

        deck.cards.where(id: day.queue_items.uncleared.select(:card_id)).count { day.remove_card! it }
      end
    end
  end
end
