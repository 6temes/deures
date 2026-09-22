# Reports the queue depths every minute, from config/recurring.yml. It runs inside Puma, where
# the collector client is the one the initializer configured, and the collector serves the
# gauges under its own "ruby_" prefix: ruby_solid_queue_pending_jobs and so on.
class SolidQueueMetricsJob < ApplicationJob
  GAUGES = {}

  queue_as :default

  def perform
    # With no collector the initializer never required the client, so PrometheusExporter is
    # not even defined: nothing to report to, rather than a NameError a minute.
    return if ENV["PROMETHEUS_COLLECTOR_HOST"].blank?

    report :solid_queue_pending_jobs, "Solid Queue jobs ready to run now", SolidQueue::ReadyExecution.count
    report :solid_queue_scheduled_jobs, "Solid Queue jobs scheduled for the future", SolidQueue::ScheduledExecution.count
    report :solid_queue_failed_jobs, "Solid Queue jobs that have failed", SolidQueue::FailedExecution.count
    report :solid_queue_oldest_pending_age_seconds, "Age in seconds of the oldest job waiting to run", oldest_pending_age
  end

  private

  def oldest_pending_age
    oldest = SolidQueue::ReadyExecution.minimum :created_at
    oldest ? (Time.current - oldest).round : 0
  end

  # Registering is a round trip, so each gauge is kept for the life of the worker process.
  def report(name, help, value)
    gauge = GAUGES[name] ||= PrometheusExporter::Client.default.register :gauge, name.to_s, help
    gauge.observe value
  end
end
