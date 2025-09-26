class CreateRounds < ActiveRecord::Migration[8.0]
  def change
    create_table :rounds do |t|
      t.references :game, null: false, foreign_key: true
      t.integer :round_number
      t.text :question
      t.integer :status
      t.datetime :started_at
      t.datetime :ended_at

      t.timestamps
    end
  end
end
