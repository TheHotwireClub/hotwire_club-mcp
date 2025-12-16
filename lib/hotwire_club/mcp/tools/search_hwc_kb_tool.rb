# frozen_string_literal: true

require "fast_mcp"

module HotwireClub
  module MCP
    module Tools
      # Tool: Search knowledge base chunks
      class SearchHwcKbTool < BaseTool
        description "Search the Hotwire Club knowledge base for chunks matching a query"

        arguments do
          required(:query).filled(:string).description("Search query string")
          optional(:category).filled(:string).description("Filter results by category")
          optional(:tags).array(:string).description("Filter results by tags (chunks must have all tags)")
          optional(:limit).filled(:integer).description("Maximum number of results (default: 8)")
        end

        def call(query:, category: nil, tags: nil, limit: 8)
          adapter.search(query: query, category: category, tags: tags, limit: limit)
        end
      end
    end
  end
end
