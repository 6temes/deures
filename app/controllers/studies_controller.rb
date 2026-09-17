class StudiesController < ApplicationController
  def show
    return render "shared/lost_identity" unless paired?

    @child = Current.child
    @study_day = StudyDay.open_for! @child
    @item = @study_day.next_item&.show!
    @celebrate = @study_day.claim_celebration!
  end
end
