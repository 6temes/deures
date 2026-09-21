require "test_helper"
require "opentelemetry/sdk"

class ApplicationJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Deures has no job backend in test and needs none: this only asserts that Active Job is
  # wired at all, so the production Solid Queue adapter has something to be an adapter for.
  class NoopJob < ApplicationJob
    def perform = nil
  end

  class TalkativeJob < ApplicationJob
    def perform = logger.info("worked")
  end

  setup do
    @events = SemanticLogger::Test::CaptureLogEvents.new
    SemanticLogger.add_appender appender: @events
  end

  teardown do
    SemanticLogger.remove_appender @events
  end

  test "the test environment enqueues rather than running a job" do
    assert_kind_of ActiveJob::QueueAdapters::TestAdapter, ActiveJob::Base.queue_adapter

    assert_enqueued_with job: NoopJob do
      NoopJob.perform_later
    end
  end

  test "a job performed inside a trace tags its log lines with that trace" do
    span = nil
    tracer.in_span("caller") do |started|
      span = started
      TalkativeJob.perform_now
    end

    assert_equal(
      {trace_id: span.context.hex_trace_id, span_id: span.context.hex_span_id},
      worked_line.named_tags
    )
  end

  test "a job performed outside a trace is tagged with nothing" do
    TalkativeJob.perform_now

    assert_empty worked_line.named_tags
  end

  private

  # The exporting SDK is only configured when an OTLP endpoint is set, which it is not in
  # test, so a recording span comes from a provider built here.
  def tracer
    OpenTelemetry::SDK::Trace::TracerProvider.new.tracer("test")
  end

  def worked_line
    SemanticLogger.flush
    @events.events.find { it.message == "worked" } || flunk("the job logged nothing")
  end
end
