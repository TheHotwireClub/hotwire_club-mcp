# frozen_string_literal: true

require "fast_mcp"

module HotwireClub
  module MCP
    module Tools
      # Tool: Find related documents
      class RelatedHwcKbDocsTool < BaseTool
        description "Find documents related to a given document or chunk based on category and tag overlap"

        arguments do
          optional(:doc_id).filled(:string).description("Document ID to find related docs for")
          optional(:chunk_id).filled(:string).description("Chunk ID to find related docs for (will use chunk's doc_id)")
          optional(:limit).filled(:integer).description("Maximum number of results (default: 5)")
        end

        def call(doc_id: nil, chunk_id: nil, limit: 5)
          raise ArgumentError, "Either doc_id or chunk_id must be provided" if doc_id.nil? && chunk_id.nil?

          adapter.related_docs(doc_id: doc_id, chunk_id: chunk_id, limit: limit)
        end
      end
    end
  end
end
