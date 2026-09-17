module Ops
  module Relief
    class Spread < Ops::Base
      include Lookups

      operation name: "relief.spread",
        description: "Spread a child's backlog evenly over the next N days, starting today.",
        example: %(Ops::Relief::Spread.call child: "Pau", days: 5, confirm: true),
        confirm: true

      def initialize(child:, days:)
        @name, @days = child, days
      end

      def perform
        refuse! "#{@days} days is not a spread — pass 1 or more" if @days < 1

        child = child! @name
        today = Date.current
        backlog = backlog_for child, today
        return "#{child.name}: nothing due today or earlier, so nothing moved" if backlog.empty?

        open_day = child.study_days.open_today.first
        counts = @days.times.to_h { [today + it, 0] }

        backlog.zip(due_dates(backlog.size, today)).each do |progress, due_on|
          progress.update!(due_on:)
          # A card that is no longer due today leaves the queue the child is already working
          # through, and taking their last card settles the day exactly as an answer would.
          open_day&.remove_card!(progress.card) if due_on > today
          counts[due_on] += 1
        end

        "#{child.name}: #{backlog.size} due today or earlier → #{counts.map { |on, count| "#{on} #{count}" }.join(", ")}"
      end

      private

      def backlog_for(child, today)
        child.assigned_progresses.where(due_on: ..today).preload(:card).to_a
      end

      # The remainder goes on the earliest days, so the day the child opens next is never the
      # lightest one and the counts never differ by more than a card.
      def due_dates(count, today)
        size, remainder = count.divmod @days

        @days.times.flat_map { |offset| Array.new(size + ((offset < remainder) ? 1 : 0), today + offset) }
      end
    end

    class Excuse < Ops::Base
      include Lookups

      operation name: "relief.excuse",
        description: "Excuse a child's day with a reason, so history shows it excused and not missed.",
        example: %(Ops::Relief::Excuse.call child: "Teo", date: "2026-09-13", reason: "holiday")

      def initialize(child:, reason:, date: nil)
        @name, @reason, @date = child, reason, date
      end

      def perform
        child = child! @name
        date = @date ? to_date(@date) : Date.current
        refuse! "#{date} has not happened yet — a day is excused on the day or after it" if date > Date.current

        day = child.study_days.find_or_initialize_by study_date: date
        before = previously day
        day.update! excuse_reason: @reason, excused_at: Time.current

        %(#{child.name} on #{date}: #{before} → excused, "#{@reason}")
      end

      private

      def previously(day)
        return %("#{day.excuse_reason}") if day.excuse_reason

        day.new_record? ? "no record" : "not excused"
      end
    end

    class Reset < Ops::Base
      include Lookups

      operation name: "relief.reset",
        description: "Reset one child's progress on one card to new, so intake offers it again.",
        example: %(Ops::Relief::Reset.call child: "Pau", deck: "Addition to 100", prompt: "38 + 27")

      def initialize(child:, deck:, prompt:)
        @name, @deck, @prompt = child, deck, prompt
      end

      def perform
        child = child! @name
        card = card! deck: @deck, prompt: @prompt
        progress = CardProgress.find_by(card:, child:) ||
          refuse!("#{child.name} is not assigned #{@deck} — assign the deck first")

        before = progress.due_on ? "rung #{progress.rung}, due #{progress.due_on}" : "new"
        progress.update! due_on: nil, last_answered_on: nil, parked_on: nil, rung: 0
        # The card is not due any more, so it leaves the queue the child is already working
        # through. Left in it, the next answer would climb the progress this just reset, and
        # taking their last card settles the day exactly as an answer would.
        child.study_days.open_today.first&.remove_card!(card)

        %(#{child.name} on "#{card.prompt}": #{before} → new)
      end
    end
  end
end
