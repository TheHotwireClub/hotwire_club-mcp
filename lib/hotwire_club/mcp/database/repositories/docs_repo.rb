# frozen_string_literal: true

module HotwireClub
  module MCP
    module Database
      class DocsRepo < ROM::Repository[:docs]
        # Get all documents
        #
        # @return [Array] Array of all documents
        def all
          container.relations[:docs].to_a
        end

        # Get a document by ID
        #
        # @param id [String] Document ID
        # @return [Hash, ROM::Struct::Doc, nil] Document or nil if not found
        def by_id(id)
          return nil if id.nil? || id.empty?

          container.relations[:docs].where(id: id).one
        end

        # List documents with optional filters
        #
        # @param category [String, nil] Filter by category
        # @param tags [Array<String>] Filter by tags (documents must have all tags)
        # @param limit [Integer] Maximum number of results (default: 20)
        # @param offset [Integer] Number of results to skip (default: 0)
        # @return [Array] Array of documents
        def list(category: nil, tags: [], limit: 20, offset: 0)
          relation = container.relations[:docs]
          relation = relation.where(category: category) if category
          relation = apply_tags_filter(relation, tags) if tags.any?
          relation.limit(limit).offset(offset).to_a
        end

        # Get all unique categories
        #
        # @return [Array<String>] Array of unique category names
        def categories
          container.relations[:docs]
                   .select(:category)
                   .distinct
                   .where { category.not(nil) }
                   .map { |r| r[:category] }
                   .compact
        end

        # Find related documents based on category and tag overlap
        #
        # @param doc_id [String, nil] Document ID to find related docs for
        # @param chunk_id [String, nil] Chunk ID to find related docs for (will use chunk's doc_id)
        # @param limit [Integer] Maximum number of results
        # @return [Array] Array of related documents
        def related_docs(limit:, doc_id: nil, chunk_id: nil)
          source_doc_id = resolve_source_doc_id(doc_id, chunk_id)
          return [] unless source_doc_id

          source_info = get_source_doc_info(source_doc_id)
          return [] unless source_info

          matching_doc_ids = find_matching_doc_ids(source_doc_id, source_info[:tags])
          return [] if matching_doc_ids.empty?

          container.relations[:docs]
                   .where(category: source_info[:category])
                   .where(id: matching_doc_ids)
                   .limit(limit)
                   .to_a
        end

        private

        def apply_tags_filter(relation, tags)
          return relation if tags.empty?

          doc_ids_with_all_tags = find_doc_ids_with_all_tags(tags)
          return relation.where(id: []) if doc_ids_with_all_tags.empty?

          relation.where(id: doc_ids_with_all_tags)
        end

        def find_doc_ids_with_all_tags(tags)
          return [] if tags.empty?

          doc_tags
            .where(tag: tags)
            .select(:doc_id)
            .group(:doc_id)
            .having { count.function.* >= tags.length }
            .map { |r| r[:doc_id] }
        end

        def resolve_source_doc_id(doc_id, chunk_id)
          return doc_id if doc_id && !chunk_id
          return nil if chunk_id.nil?

          chunk = chunks.where(chunk_id: chunk_id).one
          return nil unless chunk

          chunk[:doc_id] || chunk.doc_id
        end

        def get_source_doc_info(source_doc_id)
          source_doc = container.relations[:docs].where(id: source_doc_id).one
          return nil unless source_doc

          source_category = source_doc[:category] || source_doc.category
          source_tags = doc_tags.where(doc_id: source_doc_id).map { |r| r[:tag] }.compact

          return nil if source_category.nil? || source_tags.empty?

          {category: source_category, tags: source_tags}
        end

        def find_matching_doc_ids(source_doc_id, source_tags)
          return [] if source_tags.empty?

          doc_tags
            .where(tag: source_tags)
            .select(:doc_id)
            .distinct
            .to_a
            .map { |r| r[:doc_id] || r.doc_id }
            .compact
            .reject { |id| id == source_doc_id }
        end

        def doc_tags
          container.relations[:doc_tags]
        end

        def chunks
          container.relations[:chunks]
        end
      end
    end
  end
end
