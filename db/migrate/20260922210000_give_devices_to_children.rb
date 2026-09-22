class GiveDevicesToChildren < ActiveRecord::Migration[8.1]
  def change
    add_reference :devices, :child, null: false, foreign_key: true
    remove_reference :devices, :pairing_link, null: false, foreign_key: true

    add_column :pairing_links, :claimed_at, :datetime
    remove_column :pairing_links, :revoked_at, :datetime
  end
end
