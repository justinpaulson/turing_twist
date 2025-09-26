class CreatePlayers < ActiveRecord::Migration[8.0]
  def change
    create_table :players do |t|
      t.references :game, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.boolean :is_ai, default: false
      t.boolean :is_eliminated, default: false
      t.text :ai_persona

      t.timestamps
    end
  end
end
