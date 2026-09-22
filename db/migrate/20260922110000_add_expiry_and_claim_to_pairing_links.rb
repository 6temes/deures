class AddExpiryAndClaimToPairingLinks < ActiveRecord::Migration[8.1]
  def change
    add_column :pairing_links, :claimed_at, :datetime
    add_column :pairing_links, :expires_at, :datetime
    change_column_null :pairing_links, :expires_at, false
  end
end
