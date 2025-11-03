class MigrateVotesFromRoundToGame < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Add game_id column as nullable first
    add_column :votes, :game_id, :integer

    # Step 2: Populate game_id from round_id
    # For each vote, set game_id to the game_id of its round
    execute <<-SQL
      UPDATE votes
      SET game_id = (
        SELECT game_id FROM rounds WHERE rounds.id = votes.round_id
      )
    SQL

    # Step 3: Make game_id NOT NULL and add index
    change_column_null :votes, :game_id, false
    add_index :votes, :game_id

    # Step 4: Add foreign key
    add_foreign_key :votes, :games

    # Step 5: Remove round_id column and its index
    remove_index :votes, :round_id
    remove_column :votes, :round_id
  end

  def down
    # Add round_id back as nullable
    add_column :votes, :round_id, :integer

    # Populate round_id (this might not be perfect as we lose the original round association)
    # We'll just use the first voting round of each game
    execute <<-SQL
      UPDATE votes
      SET round_id = (
        SELECT id FROM rounds
        WHERE rounds.game_id = votes.game_id
        AND rounds.status = 2
        LIMIT 1
      )
    SQL

    # Make round_id NOT NULL and add index
    change_column_null :votes, :round_id, false
    add_index :votes, :round_id
    add_foreign_key :votes, :rounds

    # Remove game_id
    remove_foreign_key :votes, :games
    remove_index :votes, :game_id
    remove_column :votes, :game_id
  end
end
