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
class Deck < ApplicationRecord
  has_many :cards, dependent: :destroy
  has_many :deck_assignments, dependent: :destroy
  has_many :children, through: :deck_assignments

  validates :name, presence: true, uniqueness: true
end
