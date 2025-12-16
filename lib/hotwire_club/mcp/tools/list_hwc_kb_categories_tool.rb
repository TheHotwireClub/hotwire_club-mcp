# frozen_string_literal: true

require "fast_mcp"

module HotwireClub
  module MCP
    module Tools
      # Tool: List all categories
      class ListHwcKbCategoriesTool < BaseTool
        description "List all unique categories from the knowledge base"

        def call
          adapter.list_categories
        end
      end
    end
  end
end
