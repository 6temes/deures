require "test_helper"

# == Schema Information
#
# Table name: attempts
#
#  id                :integer          not null, primary key
#  accepted_keys     :json             not null
#  answer            :text             not null
#  answer_key        :string           not null
#  attempt_index     :integer          not null
#  prompt            :text             not null
#  seconds_to_answer :float            not null
#  showing_token     :string           not null
#  study_date        :date             not null
#  verdict           :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  card_id           :integer
#  child_id          :integer          not null
#
# Indexes
#
#  index_attempts_on_card_id                  (card_id)
#  index_attempts_on_child_id_and_study_date  (child_id,study_date)
#  index_attempts_on_lapses                   (child_id,card_id,study_date) WHERE attempt_index = 1 AND verdict = 'wrong'
#  index_attempts_on_showing_token            (showing_token) UNIQUE
#
# Foreign Keys
#
#  card_id   (card_id => cards.id)
#  child_id  (child_id => children.id)
#
# Check Constraints
#
#  attempt_index_is_positive          (attempt_index >= 1)
#  seconds_to_answer_is_not_negative  (seconds_to_answer >= 0)
#
class AttemptTest < ActiveSupport::TestCase
  test "updating an attempt raises" do
    attempt = attempts(:pau_sum_38_27_wrong)

    assert_raises ActiveRecord::ReadonlyAttributeError do
      attempt.update! answer: "65", verdict: "correct"
    end
    assert_equal "56", attempt.reload.answer
  end

  test "destroying an attempt is aborted" do
    attempt = attempts(:pau_sum_38_27_wrong)

    assert_no_difference -> { Attempt.count } do
      assert_not attempt.destroy
    end
    assert_raises ActiveRecord::RecordNotDestroyed do
      attempt.destroy!
    end
  end

  test "records the normalized key of the raw typed string" do
    attempt = children(:pau).attempts.create!(
      card: cards(:sum_23_19),
      study_date: Date.new(2026, 9, 14),
      prompt: "23 + 19",
      accepted_keys: ["42"],
      answer: "０４２",
      verdict: "correct",
      seconds_to_answer: 3.1,
      attempt_index: 1,
      showing_token: "showing-pau-23-19-today"
    )

    assert_equal "０４２", attempt.answer
    assert_equal "42", attempt.answer_key
  end

  test "two attempts cannot share a showing token" do
    duplicate = children(:pau).attempts.new(
      card: cards(:sum_38_27),
      study_date: Date.new(2026, 9, 14),
      prompt: "38 + 27",
      accepted_keys: ["65"],
      answer: "65",
      verdict: "correct",
      seconds_to_answer: 2.0,
      attempt_index: 2,
      showing_token: attempts(:pau_sum_38_27_wrong).showing_token
    )

    assert_not duplicate.valid?
    assert duplicate.errors[:showing_token].any?
  end

  test "an attempt survives the deletion of a never-attempted card in the same deck" do
    attempt = attempts(:pau_sum_38_27_wrong)
    cards(:difference_7_7).destroy!

    assert_equal cards(:sum_38_27), attempt.reload.card
  end
end
