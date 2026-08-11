class CreateMemories < ActiveRecord::Migration[8.1]
  def change
    create_table :memories do |t|
      t.string :title
      t.text :description
      t.boolean :archived
      t.references :superseded_by, null: true, foreign_key: { to_table: :memories }
      t.boolean :forgotten
      t.timestamp :last_recalled_at
      t.integer :recall_count

      t.timestamps
    end
  end
end
