class AddCharacterToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :character_name, :string
    add_column :players, :character_avatar, :string
  end
end
