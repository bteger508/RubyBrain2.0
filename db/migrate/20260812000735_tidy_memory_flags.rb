class TidyMemoryFlags < ActiveRecord::Migration[8.1]
  def up
    remove_column :memories, :archived

    # The flags were nullable with no default, so every existing row reads NULL
    # and would slip past a `where(forgotten: false)`. Backfill, then make the
    # absence of a value impossible.
    execute "UPDATE memories SET forgotten = FALSE WHERE forgotten IS NULL"
    execute "UPDATE memories SET recall_count = 0 WHERE recall_count IS NULL"

    change_column_default :memories, :forgotten, false
    change_column_null :memories, :forgotten, false
    change_column_default :memories, :recall_count, 0
    change_column_null :memories, :recall_count, false

    # A memory that has never been recalled has no last_recalled_at, so this one
    # stays nullable.
    change_column :memories, :last_recalled_at, :datetime

    change_column_null :memories, :title, false
    change_column_null :memories, :description, false

    add_index :memories, :forgotten
    add_index :memories, :created_at
  end

  def down
    remove_index :memories, :created_at
    remove_index :memories, :forgotten

    change_column_null :memories, :description, true
    change_column_null :memories, :title, true
    change_column :memories, :last_recalled_at, :datetime, precision: nil

    change_column_null :memories, :recall_count, true
    change_column_default :memories, :recall_count, nil
    change_column_null :memories, :forgotten, true
    change_column_default :memories, :forgotten, nil

    add_column :memories, :archived, :boolean
  end
end
