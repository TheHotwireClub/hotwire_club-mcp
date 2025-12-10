# frozen_string_literal: true

module HotwireClub
  module MCP
    # Data class representing a single chunk of a document
    Chunk = Data.define(:id, :doc_id, :title, :category, :tags, :position, :text)
  end
end
