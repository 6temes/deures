class SimplifyPairingLinksToGeneratedTokens < ActiveRecord::Migration[8.1]
  def change
    remove_index :pairing_links, :token_digest, unique: true
    remove_column :pairing_links, :token_digest, :string, null: false
    remove_column :pairing_links, :expires_at, :datetime, null: false
    remove_column :pairing_links, :claimed_at, :datetime
  end
end
