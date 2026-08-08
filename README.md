# Brain

Brain is a general-purpose AI memory engine. AI agents access Brain through its MCP server. The MCP server gives AI agents a few tools. Brain also exposes a dashboard that allows users to search, view, update and delete memories.

## MCP Tools

### Record(title, description)
Record a memory for later recall

### Recall()
Recall observations by keywords or time ranges. Parameters are TBD.

## Design
Brain uses a Postgres database to record and recall memories. AI agents record memories through the `Record` tool. As they learn new information, they record new memories. 

## Schema

### Memory
title: String
description: Text
created_at: Timestamp