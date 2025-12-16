# frozen_string_literal: true

module HotwireClub
  module MCP
    module Database
      class ChunksRepo < ROM::Repository[:chunks]
        # Get a chunk by ID
        #
        # @param chunk_id [String] Chunk ID
        # @return [Hash, ROM::Struct::Chunk, nil] Chunk or nil if not found
        def by_id(chunk_id)
          return nil if chunk_id.nil? || chunk_id.empty?

          container.relations[:chunks].where(chunk_id: chunk_id).one
        end

        # Search chunks using full-text search with optional filters
        #
        # @param query [String] Search query
        # @param category [String, nil] Filter by category
        # @param tags [Array<String>] Filter by tags (chunks must have all tags)
        # @param limit [Integer] Maximum number of results (default: 8)
        # @return [Array] Array of matching chunks
        def search(query:, category: nil, tags: [], limit: 8)
          query = query.to_s.strip
          return [] if query.empty?

          chunks_relation = container.relations[:chunks]
          relation = chunks_relation.full_text_search(query)
          relation = apply_category_filter(relation, category)
          relation = apply_tags_filter(relation, tags) if tags.any?
          relation.limit(limit).to_a
        end

        private

        def apply_category_filter(relation, category)
          return relation unless category

          relation.where(category: category)
        end

        def apply_tags_filter(relation, filter_tags)
          return relation if filter_tags.empty?

          filter_tags.each do |tag_value|
            next if tag_value.nil? || tag_value.empty?

            relation = relation.where(build_tag_condition(tag_value))
          end
          relation
        end

        def build_tag_condition(tag_value)
          tags_col = Sequel.qualify(:chunks, :tags)
          Sequel.|(
            Sequel.like(tags_col, "%,#{tag_value},%"),
            Sequel.|(
              Sequel.like(tags_col, "#{tag_value},%"),
              Sequel.|(
                Sequel.like(tags_col, "%,#{tag_value}"),
                Sequel.qualify(:chunks, :tags) => tag_value,
              ),
            ),
          )
        end
      end
    end
  end
end
