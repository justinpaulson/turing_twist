class AddVotingStartedAtToGames < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :voting_started_at, :datetime
  end
end
