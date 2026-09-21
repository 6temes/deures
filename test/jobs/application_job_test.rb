require "test_helper"

class ApplicationJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Deures has no job backend in test and needs none: this only asserts that Active Job is
  # wired at all, so the production Solid Queue adapter has something to be an adapter for.
  class NoopJob < ApplicationJob
    def perform = nil
  end

  test "the test environment enqueues rather than running a job" do
    assert_kind_of ActiveJob::QueueAdapters::TestAdapter, ActiveJob::Base.queue_adapter

    assert_enqueued_with job: NoopJob do
      NoopJob.perform_later
    end
  end
end
