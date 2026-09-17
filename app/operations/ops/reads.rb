module Ops
  # Everything the agent asks about the children. Nothing in here writes, so no read takes a
  # confirmation keyword.
  module Reads
    # What every read shares. Not an operation itself: it declares nothing into the registry.
    class Read < Ops::Base
      include Lookups

      private

      def today
        Date.current
      end

      def child
        @_child ||= child! @child_name
      end

      def assigned_progresses(of = child)
        of.assigned_progresses.order("card_progresses.id")
      end
    end

    class Status < Read
      # More than a child clears in a sitting, so the backlog wants spreading before they open
      # the app and meet all of it.
      BACKLOG = 30

      operation name: "reads.status",
        description: "Every child today: the time they finished, or the cards they have left.",
        example: %(Ops::Reads::Status.call)

      def perform
        children = Child.order(:name).to_a
        width = children.map { it.name.length }.max || 0

        ["#{today} #{Time.zone.name}", *children.map { "  #{it.name.ljust(width)}  #{standing_of it}" }].join("\n")
      end

      private

      def standing_of(child)
        day = child.study_days.find_by(study_date: today)
        return "done #{day.done_at.strftime("%H:%M")}" if day&.done_at

        # A child who has not opened the app today has no queue yet, so what faces them is
        # everything due: today's cards and every day they missed. The row is not the answer to
        # whether they have opened it — excusing a day writes one for a child who never did.
        opened = day&.first_opened_at
        count = opened ? day.remaining_count : assigned_progresses(child).where(due_on: ..today).count
        "#{count} #{opened ? "left" : "due, not opened"}#{"  backlog" if count > BACKLOG}"
      end
    end

    class Progress < Read
      # Lapses are counted from the attempt log on every read. The window moves with the day, so
      # a column counting them would be wrong tomorrow.
      WINDOW = 30

      operation name: "reads.progress",
        description: "One child's cards, weakest first: most lapses in 30 days, then lowest rung.",
        example: %(Ops::Reads::Progress.call child: "Pau")

      def initialize(child:)
        @child_name = child
      end

      def perform
        lapses = lapses_by_card
        weakest_first = assigned_progresses.includes(:card).to_a.each_with_index
          .sort_by { |progress, order| [-lapses[progress.card_id].to_i, progress.rung, order] }

        ["#{child.name}, weakest first (lapses in #{WINDOW} days)",
          *weakest_first.flat_map { |progress, _| lines_for progress, lapses[progress.card_id].to_i }].join("\n")
      end

      private

      def lapses_by_card
        child.attempts.wrong
          .where(attempt_index: 1, study_date: (today - WINDOW + 1)..today)
          .group(:card_id).count
      end

      def lines_for(progress, lapses)
        line = "  #{"#{lapses} #{"lapse".pluralize(lapses)}".ljust(8)}  rung #{progress.rung}  " \
          "#{(progress.due_on ? "due #{progress.due_on}" : "new").ljust(14)}  #{progress.card.prompt}"
        return [line] unless progress.parked_on

        [line, "    parked #{progress.parked_on}: #{typed_on(progress).join(", ")} " \
          "(want #{progress.card.accepted_keys.first})"]
      end

      def typed_on(progress)
        child.attempts
          .where(card_id: progress.card_id, study_date: progress.parked_on)
          .order(:attempt_index).pluck(:answer)
      end
    end

    class Attempts < Read
      # Longer than this is the child walking off mid-card rather than answering slowly, and
      # averaging it in would describe nothing that happened.
      WALKED_AWAY = 120

      operation name: "reads.attempts",
        description: "One child's attempts since a date, with the average time to answer.",
        example: %(Ops::Reads::Attempts.call child: "Pau", since: "2026-09-01")

      def initialize(child:, since:)
        @child_name, @since = child, since
      end

      def perform
        since = Date.parse(@since.to_s)
        attempts = child.attempts.where(study_date: since..).order(:study_date, :created_at, :id).to_a

        [heading(attempts, since), *attempts.map { line_for it }, average_of(attempts)].join("\n")
      end

      private

      def heading(attempts, since)
        "#{child.name}, #{attempts.size} #{"attempt".pluralize(attempts.size)} since #{since}, " \
          "#{attempts.count(&:wrong?)} wrong"
      end

      def line_for(attempt)
        "  #{attempt.study_date}  #{(attempt.correct? ? "ok" : "wrong").ljust(5)}  " \
          "#{timing_of(attempt).ljust(6)}  #{attempt.prompt} = #{attempt.answer}"
      end

      def timing_of(attempt)
        walked_away?(attempt) ? "away" : "#{attempt.seconds_to_answer.round(1)}s"
      end

      def average_of(attempts)
        timed = attempts.reject { walked_away? it }
        away = ", #{attempts.size - timed.size} walked away" if timed.size < attempts.size
        return "  no average yet#{away}" if timed.empty?

        average = (timed.sum(&:seconds_to_answer) / timed.size).round(1)
        "  average #{average}s over #{timed.size} #{"answer".pluralize(timed.size)}#{away}"
      end

      def walked_away?(attempt)
        attempt.seconds_to_answer > WALKED_AWAY
      end
    end

    class History < Read
      operation name: "reads.history",
        description: "One child's days, from their first to yesterday: done, excused, or missed.",
        example: %(Ops::Reads::History.call child: "Pau")

      def initialize(child:)
        @child_name = child
      end

      def perform
        yesterday = today - 1
        days = child.study_days.where(study_date: ..yesterday).order(:study_date).index_by(&:study_date)
        dates = (child.created_on..yesterday).to_a
        states = dates.to_h { [it, state_of(days[it])] }

        ["#{child.name}, #{child.created_on} to #{yesterday}",
          *dates.map { "  #{it}  #{label_for states[it], days[it]}" }, tally_of(states.values)].join("\n")
      end

      private

      # Nothing records a missed day. It is the absence of a done record on a day nobody excused.
      def state_of(day)
        return :done if day&.done_at
        return :excused if day&.excused_at

        :missed
      end

      def label_for(state, day)
        (state == :excused) ? "excused (#{day.excuse_reason})" : state.to_s
      end

      def tally_of(states)
        counted = states.tally

        "  #{counted[:done].to_i} done, #{counted[:excused].to_i} excused, #{counted[:missed].to_i} missed"
      end
    end

    class Forecast < Read
      DAYS = 14

      operation name: "reads.forecast",
        description: "One child's next 14 days: what falls due each day, and what is still unseen.",
        example: %(Ops::Reads::Forecast.call child: "Pau")

      def initialize(child:)
        @child_name = child
      end

      def perform
        due_dates = assigned_progresses.where.not(due_on: nil).pluck(:due_on)
        unseen = assigned_progresses.where(due_on: nil).count
        per_day = due_dates.tally

        ["#{child.name}, next #{DAYS} days",
          *(today...today + DAYS).map { row_for it, per_day, due_dates },
          "  #{unseen} unseen #{"card".pluralize(unseen)} remaining"].join("\n")
      end

      private

      # Everything overdue is due today, so today's row carries it. Counting only the cards
      # dated today would promise a fortnight lighter than the child's first open will be.
      def row_for(date, per_day, due_dates)
        count = (date == today) ? due_dates.count { it <= today } : per_day[date].to_i

        "  #{date} #{date.strftime("%a")}  #{count.to_s.rjust(3)}#{"  today" if date == today}"
      end
    end
  end
end
