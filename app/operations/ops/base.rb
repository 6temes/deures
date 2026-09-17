module Ops
  # Every operation the agent runs is one of these. A subclass declares itself into the
  # registry and implements `perform`; what each of them has to do the same way — the
  # household zone, the transaction, the one summary line, the confirmation — is here.
  class Base
    class Refused < StandardError; end

    # IRB echoes what an operation returns, immediately after the operation has printed
    # its summary, so nothing in here repeats it.
    Result = Data.define(:operation, :state, :summary) do
      def inspect = "#<Ops #{operation} #{state}>"
    end

    class << self
      attr_reader :description, :example, :operation_name

      def operation(name:, description:, example:, confirm: false)
        @operation_name, @description, @example, @confirm = name, description, example, confirm

        Ops.registry.add self
      end

      def confirmation_required?
        @confirm
      end

      def call(**arguments)
        new(**arguments.except(:confirm)).call confirmed: arguments.fetch(:confirm, false)
      end
    end

    # An unconfirmed operation does its whole job and throws it away, so the plan it prints
    # is the summary the confirmed run will print and not a second guess at it.
    def call(confirmed:)
      planning = self.class.confirmation_required? && !confirmed

      Household.with_zone do
        summary = nil

        # requires_new, because every test runs inside the fixture transaction and a plain
        # nested transaction swallows the rollback: the plan would then write for real.
        ActiveRecord::Base.transaction requires_new: true do
          summary = perform
          raise ActiveRecord::Rollback if planning
        end

        announce summary, planning
      end
    end

    private

    def refuse!(message)
      raise Refused, message
    end

    # A date arrives as the string an operation's example shows, or as a Date the console
    # already has in hand.
    def to_date(value)
      value.is_a?(Date) ? value : Date.parse(value)
    end

    def announce(summary, planning)
      line = planning ? "plan (nothing changed, pass confirm: true): #{summary}" : summary
      puts line

      Result.new operation: self.class.operation_name, state: planning ? :planned : :done, summary: line
    end
  end
end
