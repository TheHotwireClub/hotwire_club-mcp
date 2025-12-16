# frozen_string_literal: true

require "sequel"

module HotwireClub
  module MCP
    module Database
      # Database Adapter providing MCP-facing API
      #
      # This adapter wraps the ROM repositories and provides a clean interface
      # for searching chunks, listing documents, categories, and tags.
      class Adapter
        # Initialize the adapter with a ROM container
        #
        # @param container [ROM::Container] ROM container instance
        def initialize(container)
          @container = container
          @chunks_repo = ChunksRepo.new(container)
          @docs_repo = DocsRepo.new(container)
          @tags_repo = TagsRepo.new(container)
        end

        # Search chunks using full-text search with optional filters
        #
        # @param query [String] Search query
        # @param category [String, nil] Filter by category
        # @param tags [Array<String>, nil] Filter by tags (chunks must have all tags)
        # @param limit [Integer] Maximum number of results (default: 8)
        # @return [Array<Hash>] Array of result hashes with keys:
        #   - chunk_id [String]
        #   - doc_id [String]
        #   - title [String, nil]
        #   - category [String, nil]
        #   - tags [Array<String>]
        #   - position [Integer]
        #   - score [Numeric] FTS5 relevance score
        #   - snippet [String] First 400 characters of text
        #   - updated_at [Time, String, nil] From doc (may be nil if field doesn't exist)
        #   - url [String, nil] From doc (may be nil if field doesn't exist)
        def search(query:, category: nil, tags: nil, limit: 8)
          query = query.to_s.strip
          return [] if query.empty?

          tags = Array(tags).compact.reject(&:empty?)
          escaped_query = escape_fts5_query(query)
          dataset = build_search_dataset(escaped_query, category, tags, limit)

          dataset.to_a.map { |row| format_search_result(row) }
        end

        # Get a single chunk by ID
        #
        # @param chunk_id [String] Chunk ID
        # @return [Hash, nil] Chunk hash or nil if not found
        def get_chunk(chunk_id:)
          return nil if chunk_id.nil? || chunk_id.to_s.empty?

          chunk = @chunks_repo.by_id(chunk_id)
          return nil unless chunk

          format_chunk_result(chunk)
        end

        # List all unique categories from documents
        #
        # @return [Array<String>] Array of category names
        def list_categories
          @docs_repo.categories
        end

        # List all tags
        #
        # @return [Array<String>] Array of tag names
        def list_tags
          @container.relations[:tags].select(:name).map { |row| row[:name] || row.name }
        end

        # List documents with optional filters
        #
        # @param category [String, nil] Filter by category
        # @param tags [Array<String>, nil] Filter by tags (documents must have all tags)
        # @param limit [Integer] Maximum number of results (default: 20)
        # @param offset [Integer] Number of results to skip (default: 0)
        # @return [Array] Array of documents
        def list_docs(category: nil, tags: nil, limit: 20, offset: 0)
          tags = Array(tags).compact.reject(&:empty?)
          @docs_repo.list(category: category, tags: tags, limit: limit, offset: offset)
        end

        # Find related documents based on category and tag overlap
        #
        # @param doc_id [String, nil] Document ID to find related docs for
        # @param chunk_id [String, nil] Chunk ID to find related docs for (will use chunk's doc_id)
        # @param limit [Integer] Maximum number of results (default: 5)
        # @return [Array] Array of related documents
        def related_docs(doc_id: nil, chunk_id: nil, limit: 5)
          # Prioritize doc_id over chunk_id if both are provided
          effective_chunk_id = doc_id ? nil : chunk_id
          @docs_repo.related_docs(doc_id: doc_id, chunk_id: effective_chunk_id, limit: limit)
        end

        private

        # Format a search result row into the expected hash format
        #
        # @param row [Hash, ROM::Struct] Row from database query
        # @return [Hash] Formatted result hash
        def format_search_result(row)
          chunk_id = safe_get(row, :chunk_id)
          doc_id = safe_get(row, :doc_id)
          text = safe_get(row, :text) || ""

          # Get doc for updated_at and url (fields don't exist yet, so will be nil)
          doc = get_doc(doc_id)
          updated_at = safe_get_doc_field(doc, :updated_at)
          url = safe_get_doc_field(doc, :url)

          {
            "chunk_id"   => chunk_id,
            "doc_id"     => doc_id,
            "title"      => safe_get(row, :title),
            "category"   => safe_get(row, :category),
            "tags"       => parse_tags(safe_get(row, :tags)),
            "position"   => safe_get(row, :position),
            "score"      => safe_get(row, :score) || 0.0,
            "snippet"    => text[0, 400],
            "updated_at" => updated_at,
            "url"        => url,
          }
        end

        # Safely get a value from a hash or struct
        #
        # @param obj [Hash, Object] Object to get value from
        # @param key [Symbol] Key to get
        # @return [Object, nil] Value or nil
        def safe_get(obj, key)
          return nil unless obj

          if obj.is_a?(Hash)
            obj[key] || obj[key.to_s]
          elsif obj.respond_to?(key)
            obj.public_send(key)
          elsif obj.respond_to?(:[])
            obj[key] rescue nil
          end
        end

        # Safely get a field from a doc (handles missing attributes)
        #
        # @param doc [Hash, ROM::Struct, nil] Document object
        # @param field [Symbol] Field name
        # @return [Object, nil] Field value or nil
        def safe_get_doc_field(doc, field)
          return nil unless doc

          safe_get(doc, field)
        rescue Dry::Struct::MissingAttributeError
          # Field doesn't exist in struct schema
          nil
        end

        # Escape FTS5 query string to handle special characters
        #
        # @param query [String] Original query string
        # @return [String] Escaped query string
        def escape_fts5_query(query)
          # FTS5 special characters: ", ', &, |, etc.
          # For simple queries, wrap in double quotes to make it a phrase
          # For more complex cases, we could escape individual characters
          # For now, if query contains special chars, wrap in quotes
          if query.match?(%r{[&|"'()]})
            # Wrap in double quotes to treat as phrase
            "\"#{query.gsub('"', '""')}\""
          else
            query
          end
        end

        # Parse comma-separated tags string into array
        #
        # @param tags_string [String, nil] Comma-separated tags string
        # @return [Array<String>] Array of tag names
        def parse_tags(tags_string)
          return [] if tags_string.nil? || tags_string.to_s.empty?

          tags_string.to_s.split(",").map(&:strip).reject(&:empty?)
        end

        # Get a document by ID
        #
        # @param doc_id [String] Document ID
        # @return [Hash, ROM::Struct, nil] Document or nil if not found
        def get_doc(doc_id)
          @docs_repo.by_id(doc_id)
        end

        # Build the search dataset with filters and joins
        #
        # @param escaped_query [String] Escaped FTS5 query
        # @param category [String, nil] Category filter
        # @param tags [Array<String>] Tags filter
        # @param limit [Integer] Result limit
        # @return [Sequel::Dataset] Configured dataset
        def build_search_dataset(escaped_query, category, tags, limit)
          chunks_relation = @container.relations[:chunks]
          relation = chunks_relation.full_text_search(escaped_query)
          dataset = relation.dataset
          score_expr = Sequel.lit("bm25(chunks)")

          dataset = add_search_selects(dataset, score_expr)
          dataset = apply_category_filter(dataset, category) if category
          dataset = apply_tags_filter_to_dataset(dataset, tags) if tags.any?
          dataset = add_docs_join(dataset)
          dataset.order(Sequel.desc(score_expr)).limit(limit)
        end

        # Add select columns to search dataset
        #
        # @param dataset [Sequel::Dataset] Dataset to modify
        # @param score_expr [Sequel::SQL::Expression] Score expression
        # @return [Sequel::Dataset] Dataset with selects
        def add_search_selects(dataset, score_expr)
          dataset.select(
            Sequel.qualify(:chunks, :chunk_id),
            Sequel.qualify(:chunks, :doc_id),
            Sequel.qualify(:chunks, :title),
            Sequel.qualify(:chunks, :category),
            Sequel.qualify(:chunks, :tags),
            Sequel.qualify(:chunks, :position),
            Sequel.qualify(:chunks, :text),
            Sequel.as(score_expr, :score),
          )
        end

        # Apply category filter to dataset
        #
        # @param dataset [Sequel::Dataset] Dataset to filter
        # @param category [String] Category to filter by
        # @return [Sequel::Dataset] Filtered dataset
        def apply_category_filter(dataset, category)
          dataset.where(Sequel.qualify(:chunks, :category) => category)
        end

        # Add left join to docs table
        #
        # @param dataset [Sequel::Dataset] Dataset to modify
        # @return [Sequel::Dataset] Dataset with join
        def add_docs_join(dataset)
          dataset.left_join(:docs, id: Sequel.qualify(:chunks, :doc_id))
        end

        # Format chunk result into hash
        #
        # @param chunk [Hash, ROM::Struct] Chunk object
        # @return [Hash] Formatted chunk hash
        def format_chunk_result(chunk)
          {
            "chunk_id" => safe_get(chunk, :chunk_id),
            "doc_id"   => safe_get(chunk, :doc_id),
            "title"    => safe_get(chunk, :title),
            "category" => safe_get(chunk, :category),
            "tags"     => parse_tags(safe_get(chunk, :tags)),
            "position" => safe_get(chunk, :position),
            "text"     => safe_get(chunk, :text),
          }
        end

        # Apply tags filter to a dataset
        #
        # @param dataset [Sequel::Dataset] Dataset to filter
        # @param filter_tags [Array<String>] Tags to filter by
        # @return [Sequel::Dataset] Filtered dataset
        def apply_tags_filter_to_dataset(dataset, filter_tags)
          return dataset if filter_tags.empty?

          filter_tags.each do |tag_value|
            next if tag_value.nil? || tag_value.to_s.empty?

            dataset = apply_single_tag_filter(dataset, tag_value)
          end
          dataset
        end

        # Apply a single tag filter to dataset
        #
        # @param dataset [Sequel::Dataset] Dataset to filter
        # @param tag_value [String] Tag value to filter by
        # @return [Sequel::Dataset] Filtered dataset
        def apply_single_tag_filter(dataset, tag_value)
          tags_col = Sequel.qualify(:chunks, :tags)
          dataset.where(
            Sequel.|(
              Sequel.like(tags_col, "%,#{tag_value},%"),
              Sequel.|(
                Sequel.like(tags_col, "#{tag_value},%"),
                Sequel.|(
                  Sequel.like(tags_col, "%,#{tag_value}"),
                  tags_col => tag_value,
                ),
              ),
            ),
          )
        end
      end
    end
  end
end
