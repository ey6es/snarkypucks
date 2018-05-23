class CreateSessions < ActiveRecord::Migration
  def change
    create_table :sessions do |t|
      t.references :player, index: true, foreign_key: true
      t.string :token
      t.datetime :expires

      t.timestamps null: false
    end
  end
end
