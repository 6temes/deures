require "test_helper"

# == Schema Information
#
# Table name: decks
#
#  id         :integer          not null, primary key
#  name       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_decks_on_name  (name) UNIQUE
#
class DeckTest < ActiveSupport::TestCase
  test "a deck needs a name" do
    deck = Deck.new

    assert_not deck.valid?
    assert deck.errors[:name].any?
  end

  test "two decks cannot share a name" do
    duplicate = Deck.new name: decks(:addition).name

    assert_not duplicate.valid?
    assert duplicate.errors[:name].any?
  end
end
