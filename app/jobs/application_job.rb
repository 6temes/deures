class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # A job's log lines carry the trace they belong to, so a slow request and the work it
  # queued can be read as one thing rather than two.
  around_perform do |_job, block|
    span = OpenTelemetry::Trace.current_span

    if span.context.valid?
      SemanticLogger.named_tagged(trace_id: span.context.hex_trace_id, span_id: span.context.hex_span_id) { block.call }
    else
      block.call
    end
  end
end
