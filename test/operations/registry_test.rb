require "test_helper"

class RegistryTest < ActiveSupport::TestCase
  # Throwaway operations. The base class and the registry are what is under test; the
  # operations the household actually runs arrive in the units after this one.
  class RenameDeck < Ops::Base
    operation name: "test.rename_deck",
      description: "Rename a deck.",
      example: %(RegistryTest::RenameDeck.call deck: "Times tables", to: "Multiplication")

    def initialize(deck:, to:)
      @deck, @to = deck, to
    end

    def perform
      deck = Deck.find_by name: @deck
      refuse! %(no deck called "#{@deck}" — create it first) unless deck

      deck.update! name: @to
      "#{@deck} → #{@to}, #{Date.current}"
    end
  end

  class AddDecks < Ops::Base
    operation name: "test.add_decks",
      description: "Create several decks at once.",
      example: %(RegistryTest::AddDecks.call names: [ "Fractions" ], confirm: true),
      confirm: true

    def initialize(names:)
      @names = names
    end

    def perform
      before = Deck.count
      @names.each { Deck.create! name: it }
      "decks #{before} → #{Deck.count}"
    end
  end

  # 23:30 UTC on the 13th is 08:30 Tokyo on the 14th, the disagreement every date in this
  # app turns on.
  setup { travel_to Time.utc(2026, 9, 13, 23, 30) }

  # An operation declares itself into the registry as its class body is evaluated, and
  # autoloading outside CI is lazy, so without this the registry holds whatever the process
  # happens to have referenced — here, the two throwaways above and nothing else.
  setup { Rails.autoloaders.main.eager_load_dir Rails.root.join("app/operations") }

  test "every operation appears in the listing with a description and an example" do
    listing, = capture_io { Ops.help }

    assert_operator Ops.registry.operations.size, :>=, 2
    Ops.registry.operations.each do |operation|
      assert_includes listing, operation.operation_name
      assert_includes listing, operation.description
      assert_includes listing, operation.example
    end
  end

  test "the listing marks the operations that need confirming" do
    listing, = capture_io { Ops.help }

    assert_match(/test\.add_decks .*\(confirm\)/, listing)
    assert_no_match(/test\.rename_deck .*\(confirm\)/, listing)
  end

  test "every example in the registry runs against the fixtures without raising" do
    household = Ops.registry.operations.reject { it.operation_name.start_with? "test." }

    assert_includes household.map(&:operation_name), "cards.add"
    assert_operator household.size, :>=, 10

    Ops.registry.operations.each do |operation|
      result = nil
      capture_io { result = eval(operation.example) } # rubocop:disable Security/Eval

      assert_kind_of Ops::Base::Result, result, operation.operation_name
    end
  end

  test "a write prints exactly one summary line" do
    out, = capture_io { RenameDeck.call deck: "Times tables", to: "Multiplication" }

    assert_equal "Times tables → Multiplication, 2026-09-14\n", out
    assert_equal 1, out.lines.size
    assert_equal "Multiplication", decks(:tables).reload.name
  end

  test "the result of an operation inspects short enough not to repeat the summary" do
    result = nil
    capture_io { result = RenameDeck.call(deck: "Times tables", to: "Multiplication") }

    assert_equal "#<Ops test.rename_deck done>", result.inspect
    assert_not_includes result.inspect, result.summary
  end

  test "an operation dates itself in the household zone, not the process zone" do
    assert_equal Date.new(2026, 9, 13), Time.now.utc.to_date

    out, = Time.use_zone("UTC") { capture_io { RenameDeck.call deck: "Times tables", to: "Multiplication" } }

    assert_includes out, "2026-09-14"
  end

  test "a failing operation rolls back its transaction and prints no success line" do
    out, = capture_io do
      assert_raises ActiveRecord::RecordInvalid do
        AddDecks.call names: ["Fractions", "Addition to 100"], confirm: true
      end
    end

    assert_empty out
    assert_not Deck.exists?(name: "Fractions")
  end

  test "a refused operation says what to do instead, prints nothing, and changes nothing" do
    out, = capture_io do
      refusal = assert_raises Ops::Base::Refused do
        RenameDeck.call deck: "Division", to: "Multiplication"
      end

      assert_equal %(no deck called "Division" — create it first), refusal.message
    end

    assert_empty out
    assert_equal "Times tables", decks(:tables).reload.name
  end

  test "an operation that needs confirming prints its plan and changes nothing without it" do
    out, = capture_io { AddDecks.call names: ["Fractions"] }

    assert_equal 1, out.lines.size
    assert_includes out, "plan (nothing changed, pass confirm: true)"
    assert_includes out, "decks 2 → 3"
    assert_not Deck.exists?(name: "Fractions")
  end

  test "an operation that needs confirming runs once it is confirmed" do
    out, = capture_io { AddDecks.call names: ["Fractions"], confirm: true }

    assert_equal "decks 2 → 3\n", out
    assert Deck.exists?(name: "Fractions")
  end

  test "an operation that needs no confirming runs without the keyword" do
    capture_io { RenameDeck.call deck: "Times tables", to: "Multiplication" }

    assert_equal "Multiplication", decks(:tables).reload.name
  end
end
