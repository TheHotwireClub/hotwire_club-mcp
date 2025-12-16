# frozen_string_literal: true

require "fast_mcp"

module HotwireClub
  module MCP
    module Tools
      # Tool: List documents with optional filters
      class ListHwcKbDocsTool < BaseTool
        description "List documents from the knowledge base with optional filters"

        arguments do
          optional(:category).filled(:string).description("Filter by category")
          optional(:tags).array(:string).description("Filter by tags (documents must have all tags)")
          optional(:limit).filled(:integer).description("Maximum number of results (default: 20)")
          optional(:offset).filled(:integer).description("Number of results to skip (default: 0)")
        end

        def call(category: nil, tags: nil, limit: 20, offset: 0)
          adapter.list_docs(category: category, tags: tags, limit: limit, offset: offset)
        end
      end
    end
  end
end
