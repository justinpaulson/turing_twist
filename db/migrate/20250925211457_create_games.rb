class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.integer :status
      t.integer :round_count
      t.integer :current_round

      t.timestamps
    end
  end
end
