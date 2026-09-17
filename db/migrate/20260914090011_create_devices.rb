class CreateDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :devices do |t|
      t.references :pairing_link, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :last_seen_at
      t.datetime :forgotten_at

      t.timestamps

      t.index :token_digest, unique: true
    end
  end
end
