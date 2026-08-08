# Brain
Brain is a general-purpose AI memory engine. Brain records and recalls memories for AI agents across AI providers, sessions, and projects. AI agents access Brain through its MCP server which allows them to record, recall, update and forget memories. External systems can authenticate with API that exposes the same tools through REST. Brain also includes a mobile-first web dashboard that allows users to search, view, update and delete memories. 

## MCP Tools

### Record(title, description)
Record a memory for later recall. Record recalls and checks for near duplicates first. If there are any duplicates, the new memory supercedes the old memory. Future Recalls return the new memory, not the old one. 

### Recall()
Recall observations by keywords or time ranges. Parameters are TBD. 

### Update()
Update memories by supersession: record the new memory and link the old memory to it through the old memory's superseded_by foreign key.

### Forget(id)
Archive a memory that is no longer relevant or accurate. Mark memory.forgotten = true

## Tech Stack
- Ruby on Rails 
- Postgres with pgvector and tsvector
- Devise gem for Authentication

## Schema

### Memory
title: String
description: Text
archived: Boolean
superseded_by: ID (fk to Memory)
forgotten: Boolean
last_recalled_at: Timestamp
recall_count: Integer
created_at: Timestamp
updated_at: Timestamp