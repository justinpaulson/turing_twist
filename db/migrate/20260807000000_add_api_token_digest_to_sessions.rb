class AddApiTokenDigestToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :api_token_digest, :string
    add_index :sessions, :api_token_digest, unique: true
  end
end
