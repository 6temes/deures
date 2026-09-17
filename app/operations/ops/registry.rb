module Ops
  # What every operation declares itself into, and the plain text `Ops.help` renders.
  class Registry
    HEADING = <<~TEXT
      Deures operations. Every read and write of this app's data goes through one of
      these; nothing is created, updated, or destroyed from the console by hand.
      An operation marked (confirm) prints its plan and changes nothing until it is passed
      confirm: true.
    TEXT

    def initialize
      @operations = {}
    end

    def add(operation)
      @operations[operation.operation_name] = operation
    end

    def operations
      @operations.values.sort_by(&:operation_name)
    end

    def to_text
      [HEADING, *operations.map { entry it }].join("\n")
    end

    private

    def entry(operation)
      confirm = " (confirm)" if operation.confirmation_required?

      "  #{operation.operation_name} — #{operation.description}#{confirm}\n      #{operation.example}\n"
    end
  end
end
