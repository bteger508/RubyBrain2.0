class AddEmbeddingToMemories < ActiveRecord::Migration[8.1]
  # Fixed at the column, so it cannot drift from what the embedder returns.
  # Changing providers to one with a different width means a new migration and
  # a full re-embed; see ApplicationEmbedder::DIMENSIONS.
  DIMENSIONS = 1536

  def change
    enable_extension "vector"

    add_column :memories, :embedding, :vector, limit: DIMENSIONS

    # HNSW over cosine distance: Recall ranks by angle, and every vector the
    # embedder hands back is already unit length.
    add_index :memories, :embedding, using: :hnsw, opclass: :vector_cosine_ops,
      name: "index_memories_on_embedding_hnsw"
  end
end
