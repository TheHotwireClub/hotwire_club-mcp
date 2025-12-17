# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-17

### Added
- Initial release of HotwireClub::MCP server
- MCP tools for searching and browsing the Hotwire Club knowledge base:
  - `SearchHwcKbTool` - Search the knowledge base for chunks matching a query
  - `GetHwcKbChunkTool` - Get a single knowledge base chunk by its chunk_id
  - `ListHwcKbCategoriesTool` - List all unique categories from the knowledge base
  - `ListHwcKbTagsTool` - List all tags from the knowledge base
  - `ListHwcKbDocsTool` - List documents from the knowledge base with optional filters
  - `RelatedHwcKbDocsTool` - Find documents related to a given document or chunk based on category and tag overlap
- SQLite database builder for converting markdown documents into a searchable knowledge base
- Pre-built knowledge base database included in the gem
- Support for Claude Desktop and Cursor MCP configuration
- Full-text search using SQLite FTS5 with Porter stemming
