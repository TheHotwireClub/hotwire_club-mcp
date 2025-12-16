# frozen_string_literal: true

require_relative "mcp/version"
require_relative "mcp/doc"
require_relative "mcp/loader"
require_relative "mcp/chunk"
require_relative "mcp/chunker"
require_relative "mcp/schema"
require_relative "mcp/database"
require_relative "mcp/database/repositories/docs_repo"
require_relative "mcp/database/repositories/tags_repo"
require_relative "mcp/database/repositories/chunks_repo"
require_relative "mcp/database/adapter"
require_relative "mcp/builder"
require_relative "mcp/server"
require_relative "mcp/tools"

module HotwireClub
  module MCP
    class Error < StandardError; end
    # Your code goes here...
  end
end

# Top-level aliases for repositories (for convenience in tests and usage)
DocsRepo = HotwireClub::MCP::Database::DocsRepo
TagsRepo = HotwireClub::MCP::Database::TagsRepo
ChunksRepo = HotwireClub::MCP::Database::ChunksRepo
Adapter = HotwireClub::MCP::Database::Adapter
