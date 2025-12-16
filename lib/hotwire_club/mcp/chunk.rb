# frozen_string_literal: true

module HotwireClub
  module MCP
    # Data class representing a single chunk of a document
    Chunk = Data.define(:id, :doc_id, :title, :category, :tags, :position, :text) {
      # Create a chunk from a document section
      #
      # @param doc [Doc] The document this chunk belongs to
      # @param section_idx [Integer] The index of the section within the document
      # @param part_idx [Integer] The index of the part within the section (0 for first part)
      # @param section_title [String, nil] The title of the section
      # @param text [String] The text content of the chunk
      # @param position [Integer] The position of the chunk within the document
      # @return [Chunk] A new Chunk instance with generated ID
      def self.create_from_section(doc:, section_idx:, part_idx:, section_title:, text:, position:)
        chunk_id =
          if part_idx.zero?
            "#{doc.id}#s#{section_idx}"
          else
            "#{doc.id}#s#{section_idx}-#{part_idx}"
          end

        new(
          id:       chunk_id,
          doc_id:   doc.id,
          title:    section_title,
          category: doc.category,
          tags:     doc.tags,
          position: position,
          text:     text,
        )
      end
    }
  end
end
