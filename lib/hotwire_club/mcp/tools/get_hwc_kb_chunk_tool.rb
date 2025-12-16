# frozen_string_literal: true

require "fast_mcp"

module HotwireClub
  module MCP
    module Tools
      # Tool: Get a single chunk by ID
      class GetHwcKbChunkTool < BaseTool
        description "Get a single knowledge base chunk by its chunk_id"

        arguments do
          required(:chunk_id).filled(:string).description("Chunk ID to retrieve")
        end

        def call(chunk_id:)
          adapter.get_chunk(chunk_id: chunk_id)
        end
      end
    end
  end
end
