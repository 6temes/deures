class CreatePairingLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :pairing_links do |t|
      t.references :child, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :revoked_at

      t.timestamps

      t.index :token_digest, unique: true
    end
  end
end
