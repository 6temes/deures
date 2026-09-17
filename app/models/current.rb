class Current < ActiveSupport::CurrentAttributes
  attribute :device
  delegate :child, to: :device, allow_nil: true
end
