# frozen_string_literal: true

require "fast_mcp"

module HotwireClub
  module MCP
    module Tools
      # Tool: List all tags
      class ListHwcKbTagsTool < BaseTool
        description "List all tags from the knowledge base"

        def call
          adapter.list_tags
        end
      end
    end
  end
end
