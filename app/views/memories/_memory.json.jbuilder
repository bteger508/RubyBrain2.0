json.extract! memory, :id, :title, :description, :superseded_by_id, :forgotten, :last_recalled_at, :recall_count, :created_at, :updated_at
json.url memory_url(memory, format: :json)
