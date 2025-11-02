class AddAiPersonaIndicesToGames < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :ai_persona_indices, :json
  end
end
