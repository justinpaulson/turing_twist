class CreateVotes < ActiveRecord::Migration[8.0]
  def change
    create_table :votes do |t|
      t.references :round, null: false, foreign_key: true
      t.references :voter, null: false, foreign_key: { to_table: :players }
      t.references :voted_for, null: false, foreign_key: { to_table: :players }

      t.timestamps
    end
  end
end
