class AnswersController < ApplicationController
  # The most the number pad can type. A longer answer did not come from the pad, so it is
  # discarded rather than graded, exactly as an empty one is.
  PAD_LIMIT = 6

  def create
    return render :lost_identity unless paired?

    @child = Current.child
    @study_day = StudyDay.open_for! @child
    @attempt = gradable_item&.answer!(typed)
    @item = @study_day.next_item&.show!
    @celebrate = @study_day.claim_celebration!
  end

  private

  # A submit the pad could not have produced, and one whose token a rolled-over day has
  # stranded, are both answered with the child's current state. Anything else would leave the
  # no-connection overlay retrying behind a screen with nothing on it to tap.
  def gradable_item
    token = params[:showing_token].to_s
    return if token.empty? || typed.blank? || typed.length > PAD_LIMIT

    @study_day.queue_items.find_by showing_token: token
  end

  def typed
    params[:answer].to_s
  end
end
