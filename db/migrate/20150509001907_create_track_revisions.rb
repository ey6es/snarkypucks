class CreateTrackRevisions < ActiveRecord::Migration
  def change
    create_table :track_revisions do |t|
      t.references :track, index: true, foreign_key: true
      t.string :name
      t.text :data

      t.timestamps null: false
    end
    add_index :track_revisions, :name
  end
end
