class ChangeVotesFromRoundToGame < ActiveRecord::Migration[8.0]
  def change
    # Remove the round_id column and index
    remove_index :votes, :round_id
    remove_column :votes, :round_id, :integer

    # Add game_id column and index
    add_reference :votes, :game, null: false, foreign_key: true, index: true
  end
end
