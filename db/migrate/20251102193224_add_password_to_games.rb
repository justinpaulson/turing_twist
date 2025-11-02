class AddPasswordToGames < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :password, :string
  end
end
