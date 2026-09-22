require "test_helper"
require "minitest/mock"
# The initializer leaves the client unconfigured in test, so nothing else has asked for it.
require "prometheus_exporter/client"

class SolidQueueMetricsJobTest < ActiveSupport::TestCase
  # Stands in for the collector connection and records what the job asked it to report.
  class Collector
    attr_reader :observed

    def initialize
      @observed = {}
    end

    Gauge = Struct.new :collector, :name do
      def observe(value) = collector.observed[name] = value
    end

    def register(_type, name, _help) = Gauge.new(self, name)
  end

  setup { SolidQueueMetricsJob::GAUGES.clear }

  teardown { SolidQueueMetricsJob::GAUGES.clear }

  test "reports nothing at all when no collector is configured" do
    refusing_client do
      with_collector_host nil do
        SolidQueueMetricsJob.new.perform
      end
    end

    assert_empty SolidQueueMetricsJob::GAUGES
  end

  test "reports a gauge for each queue depth" do
    collector = report pending: 7, scheduled: 2, failed: 1, oldest: 3.minutes.ago

    assert_equal 7, collector.observed["solid_queue_pending_jobs"]
    assert_equal 2, collector.observed["solid_queue_scheduled_jobs"]
    assert_equal 1, collector.observed["solid_queue_failed_jobs"]
    assert_in_delta 180, collector.observed["solid_queue_oldest_pending_age_seconds"], 5
  end

  test "reports an age of zero when nothing is waiting" do
    collector = report pending: 0, scheduled: 0, failed: 0, oldest: nil

    assert_equal 0, collector.observed["solid_queue_oldest_pending_age_seconds"]
    assert_equal 4, collector.observed.size
  end

  private

  # The test database carries the primary schema only, so the queue tables the job counts do
  # not exist here and the depths are given rather than created.
  def report(pending:, scheduled:, failed:, oldest:)
    collector = Collector.new

    SolidQueue::ReadyExecution.stub :count, pending do
      SolidQueue::ReadyExecution.stub :minimum, oldest do
        SolidQueue::ScheduledExecution.stub :count, scheduled do
          SolidQueue::FailedExecution.stub :count, failed do
            PrometheusExporter::Client.stub :default, collector do
              with_collector_host("collector") { SolidQueueMetricsJob.new.perform }
            end
          end
        end
      end
    end

    collector
  end

  def refusing_client(&)
    PrometheusExporter::Client.stub(:default, -> { flunk "the job reached for a collector client" }, &)
  end

  def with_collector_host(host)
    was = ENV["PROMETHEUS_COLLECTOR_HOST"]
    ENV["PROMETHEUS_COLLECTOR_HOST"] = host
    yield
  ensure
    ENV["PROMETHEUS_COLLECTOR_HOST"] = was
  end
end
