class AddSearchToMemories < ActiveRecord::Migration[8.1]
  # Recall matches keywords against this, weighted so a hit in the title outranks
  # a hit buried in the description. Generated rather than maintained in Ruby, so
  # it cannot drift from the row it describes.
  SEARCHABLE = <<~SQL.squish
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'B')
  SQL

  def change
    # Trigram similarity backs Record's near-duplicate check.
    enable_extension "pg_trgm"

    add_column :memories, :searchable, :virtual, type: :tsvector, as: SEARCHABLE, stored: true
    add_index :memories, :searchable, using: :gin

    add_index :memories, :title, using: :gin, opclass: :gin_trgm_ops, name: "index_memories_on_title_trigram"
  end
end
