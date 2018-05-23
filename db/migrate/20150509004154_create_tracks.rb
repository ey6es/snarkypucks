class CreateTracks < ActiveRecord::Migration
  def change
    create_table :tracks do |t|
      t.references :creator, index: true, foreign_key: true
      t.references :published_revision, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
