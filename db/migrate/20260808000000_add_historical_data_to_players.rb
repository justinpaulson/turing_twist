class AddHistoricalDataToPlayers < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :is_virtual, :boolean, default: false, null: false
    add_column :players, :historical_data, :json

    add_index :players, :is_virtual
  end
end
