ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/pairing_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # The progress row is one star per card in the day, filled for the ones the child has
    # cleared. `within` reaches into the Turbo stream's template as well as the rendered page.
    def assert_progress(cleared:, of:, within: "#progress")
      # The row itself first: `count: 0` is satisfied by a row that is not there at all, so a
      # zero-card day would otherwise assert nothing whatsoever.
      assert_select within, count: 1
      assert_select "#{within} svg.pip", count: of
      assert_select "#{within} svg.pip-lit", count: cleared
    end
  end
end
