# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "rom"
require "securerandom"

module HotwireClub
  # Exhaustive test suite for Database Adapter
  #
  # This test suite covers all methods required by issue #20:
  # - search(query:, category:, tags:, limit:) - Full-text search with filters
  # - get_chunk(chunk_id:) - Retrieve a single chunk by ID
  # - list_categories - List all unique categories from docs
  # - list_tags - List all tags
  # - list_docs(category:, tags:, limit:, offset:) - List documents with filters
  # - related_docs(doc_id: nil, chunk_id: nil, limit: 5) - Find related documents
  #
  # Test coverage includes:
  # - Happy path scenarios for all methods
  # - Edge cases (nil values, empty strings, empty arrays)
  # - Filter combinations (category + tags, multiple tags)
  # - Pagination (limit, offset)
  # - Data validation (required fields, data types, array parsing)
  # - Security (SQL injection prevention)
  # - Error handling (nonexistent IDs, no matches)
  # - Return value formats and structures
  #
  # All tests are currently skipped until the Adapter class is implemented.
  # Remove skip statements once the Adapter class exists.
  class TestAdapter < Minitest::Test
    def setup
      # Use unique database path with UUID to ensure complete isolation
      @db_path = File.join(Dir.pwd, "db", "kb-adapter-test-#{SecureRandom.uuid}.sqlite")
      @db_dir = File.dirname(@db_path)
      FileUtils.mkdir_p(@db_dir)
      FileUtils.rm_f(@db_path)
      HotwireClub::MCP::Schema.create!(@db_path)
      @container = HotwireClub::MCP::Database.container(@db_path)
      setup_test_data
      @adapter = HotwireClub::MCP::Database::Adapter.new(@container)
    end

    def teardown
      # Clear container reference to allow garbage collection
      @container = nil
      FileUtils.rm_f(@db_path)
      FileUtils.rmdir(@db_dir) if Dir.exist?(@db_dir) && Dir.empty?(@db_dir)
    end

    def setup_test_data
      # Create test documents
      @container.relations[:docs].insert(
        id:       "doc-1",
        title:    "Ruby Programming Guide",
        category: "programming",
        summary:  "A comprehensive guide to Ruby",
        body:     "Ruby is a dynamic programming language",
        date:     "2024-01-01",
      )
      @container.relations[:docs].insert(
        id:       "doc-2",
        title:    "Python Basics",
        category: "programming",
        summary:  "Introduction to Python",
        body:     "Python is a versatile language",
        date:     "2024-01-02",
      )
      @container.relations[:docs].insert(
        id:       "doc-3",
        title:    "JavaScript Frontend",
        category: "frontend",
        summary:  "Frontend JavaScript guide",
        body:     "JavaScript powers the web",
        date:     "2024-01-03",
      )
      @container.relations[:docs].insert(
        id:       "doc-4",
        title:    "Rails Tutorial",
        category: "programming",
        summary:  "Learn Rails",
        body:     "Rails is a Ruby web framework",
        date:     "2024-01-04",
      )
      @container.relations[:docs].insert(
        id:      "doc-5",
        title:   "No Category Doc",
        summary: "Document without category",
        body:    "This document has no category",
        date:    "2024-01-05",
      )

      # Create tags
      @container.relations[:tags].insert(name: "ruby")
      @container.relations[:tags].insert(name: "rails")
      @container.relations[:tags].insert(name: "python")
      @container.relations[:tags].insert(name: "javascript")
      @container.relations[:tags].insert(name: "frontend")
      @container.relations[:tags].insert(name: "backend")

      # Create doc-tag relationships
      @container.relations[:doc_tags].insert(doc_id: "doc-1", tag: "ruby")
      @container.relations[:doc_tags].insert(doc_id: "doc-1", tag: "backend")
      @container.relations[:doc_tags].insert(doc_id: "doc-2", tag: "python")
      @container.relations[:doc_tags].insert(doc_id: "doc-2", tag: "backend")
      @container.relations[:doc_tags].insert(doc_id: "doc-3", tag: "javascript")
      @container.relations[:doc_tags].insert(doc_id: "doc-3", tag: "frontend")
      @container.relations[:doc_tags].insert(doc_id: "doc-4", tag: "ruby")
      @container.relations[:doc_tags].insert(doc_id: "doc-4", tag: "rails")
      @container.relations[:doc_tags].insert(doc_id: "doc-4", tag: "backend")

      # Create chunks with various content
      @container.relations[:chunks].insert(
        chunk_id: "doc-1#s0",
        doc_id:   "doc-1",
        title:    "Introduction to Ruby",
        text:     "Ruby is a dynamic, reflective, object-oriented, general-purpose programming language. " \
                  "It was designed and developed in the mid-1990s by Yukihiro Matsumoto in Japan. " \
                  "Ruby has a syntax that is natural to read and easy to write. " \
                  "The language is known for its elegant syntax and powerful features.",
        category: "programming",
        tags:     "ruby,backend",
        position: 0,
      )
      @container.relations[:chunks].insert(
        chunk_id: "doc-1#s1",
        doc_id:   "doc-1",
        title:    "Ruby Syntax",
        text:     "Ruby syntax is clean and readable. " \
                  "It supports multiple programming paradigms including procedural, " \
                  "object-oriented, and functional programming.",
        category: "programming",
        tags:     "ruby,backend",
        position: 1,
      )
      @container.relations[:chunks].insert(
        chunk_id: "doc-2#s0",
        doc_id:   "doc-2",
        title:    "Python Introduction",
        text:     "Python is a high-level, interpreted programming language with dynamic semantics. " \
                  "Its high-level built-in data structures, combined with dynamic typing and dynamic binding, " \
                  "make it very attractive for Rapid Application Development.",
        category: "programming",
        tags:     "python,backend",
        position: 0,
      )
      @container.relations[:chunks].insert(
        chunk_id: "doc-3#s0",
        doc_id:   "doc-3",
        title:    "JavaScript Basics",
        text:     "JavaScript is a scripting language that enables you to create dynamically updating content, " \
                  "control multimedia, animate images, and much more.",
        category: "frontend",
        tags:     "javascript,frontend",
        position: 0,
      )
      @container.relations[:chunks].insert(
        chunk_id: "doc-4#s0",
        doc_id:   "doc-4",
        title:    "Rails Framework",
        text:     "Ruby on Rails, often called Rails, is a server-side web application framework written in Ruby. " \
                  "Rails is a model-view-controller framework, providing default structures for a database, " \
                  "a web service, and web pages.",
        category: "programming",
        tags:     "ruby,rails,backend",
        position: 0,
      )
      @container.relations[:chunks].insert(
        chunk_id: "doc-5#s0",
        doc_id:   "doc-5",
        title:    "No Category Chunk",
        text:     "This chunk belongs to a document without a category.",
        category: nil,
        tags:     nil,
        position: 0,
      )
      # Add a chunk with very long text for snippet testing
      long_text = "A" * 500
      @container.relations[:chunks].insert(
        chunk_id: "doc-1#s2",
        doc_id:   "doc-1",
        title:    "Long Text Chunk",
        text:     long_text,
        category: "programming",
        tags:     "ruby,backend",
        position: 2,
      )
    end

    # Helper method to parse tags (mimics expected behavior)
    def parse_tags(tags_string)
      return [] if tags_string.nil? || tags_string.empty?

      tags_string.split(",").map(&:strip).reject(&:empty?)
    end

    # Helper method to get doc by id (mimics expected behavior)
    def get_doc(doc_id)
      @container.relations[:docs].where(id: doc_id).one
    end

    # ============================================================================
    # Tests for search(query:, category:, tags:, limit:)
    # ============================================================================

    def test_search_returns_results_with_required_fields

      results = @adapter.search(query: "Ruby", limit: 10)

      assert_kind_of Array, results
      assert_predicate results, :any?

      result = results.first

      assert_includes result.keys, "chunk_id"
      assert_includes result.keys, "doc_id"
      assert_includes result.keys, "title"
      assert_includes result.keys, "category"
      assert_includes result.keys, "tags"
      assert_includes result.keys, "position"
      assert_includes result.keys, "score"
      assert_includes result.keys, "snippet"
      assert_includes result.keys, "date"
    end

    def test_search_finds_chunks_by_query

      results = @adapter.search(query: "Ruby", limit: 10)

      assert_predicate results, :any?
      assert results.any? { |r| r["chunk_id"] == "doc-1#s0" }
    end

    def test_search_returns_chunk_id

      results = @adapter.search(query: "Ruby", limit: 10)

      assert_predicate results, :any?
      assert results.all? { |r| r["chunk_id"].is_a?(String) }
      assert results.all? { |r| !r["chunk_id"].empty? }
    end

    def test_search_returns_doc_id

      results = @adapter.search(query: "Ruby", limit: 10)

      assert_predicate results, :any?
      assert results.all? { |r| r["doc_id"].is_a?(String) }
      assert results.all? { |r| !r["doc_id"].empty? }
    end

    def test_search_returns_title

      results = @adapter.search(query: "Ruby", limit: 10)

      assert_predicate results, :any?
      assert results.all? { |r| r["title"].is_a?(String) || r["title"].nil? }
    end

    def test_search_returns_category

      results = @adapter.search(query: "Ruby", limit: 10)

      assert_predicate results, :any?
      assert results.all? { |r| r["category"].is_a?(String) || r["category"].nil? }
    end

    def test_search_returns_parsed_tags_as_array

      results = @adapter.search(query: "Ruby", limit: 10)

      assert_predicate results, :any?
      assert results.all? { |r| r["tags"].is_a?(Array) }
      # Check that tags are parsed correctly
      ruby_result = results.find { |r| r["chunk_id"] == "doc-1#s0" }
      assert_includes ruby_result["tags"], "ruby" if ruby_result
      assert_includes ruby_result["tags"], "backend" if ruby_result
    end

    def test_search_returns_position

      results = @adapter.search(query: "Ruby", limit: 10)

      assert_predicate results, :any?
      assert results.all? { |r| r["position"].is_a?(Integer) }
    end

    def test_search_returns_score

      results = @adapter.search(query: "Ruby", limit: 10)

      assert_predicate results, :any?
      assert results.all? { |r| r["score"].is_a?(Numeric) }
      # Scores can be positive or negative (bm25 can return negative values)
      # Just verify they're numeric
    end

    def test_search_returns_snippet_truncated_to_400_chars

      results = @adapter.search(query: "Ruby", limit: 10)

      assert_predicate results, :any?
      assert results.all? { |r| r["snippet"].is_a?(String) }
      assert results.all? { |r| r["snippet"].length <= 400 }

      # Find the long text chunk
      long_result = results.find { |r| r["chunk_id"] == "doc-1#s2" }
      assert_equal 400, long_result["snippet"].length if long_result
    end

    def test_search_returns_snippet_from_text_start

      results = @adapter.search(query: "Ruby", limit: 10)

      result = results.find { |r| r["chunk_id"] == "doc-1#s0" }
      assert result["snippet"].start_with?("Ruby is a dynamic") if result
    end

    def test_search_returns_date_from_doc

      results = @adapter.search(query: "Ruby", limit: 10)

      assert_predicate results, :any?
      # date might be nil if doc doesn't have a date
      date_valid = results.all? { |r|
        r["date"].nil? || r["date"].is_a?(Time) || r["date"].is_a?(String) || r["date"].is_a?(Date)
      }

      assert date_valid
    end

    def test_search_returns_date_matches_doc_date

      results = @adapter.search(query: "Ruby", limit: 10)

      return if results.empty?

      result = results.first
      doc = @container.relations[:docs].where(id: result["doc_id"]).one
      expected_date = doc[:date] || doc.date

      assert_equal expected_date, result["date"]
    end

    def test_search_filters_by_category

      results = @adapter.search(query: "programming", category: "programming", limit: 10)

      assert_predicate results, :any?
      assert results.all? { |r| r["category"] == "programming" }
    end

    def test_search_filters_by_single_tag

      results = @adapter.search(query: "language", tags: ["ruby"], limit: 10)

      assert_predicate results, :any?
      assert results.all? { |r| r["tags"].include?("ruby") }
    end

    def test_search_filters_by_multiple_tags

      results = @adapter.search(query: "framework", tags: ["ruby", "rails"], limit: 10)

      assert_predicate results, :any?
      assert results.all? { |r| r["tags"].include?("ruby") && r["tags"].include?("rails") }
    end

    def test_search_combines_category_and_tags

      results = @adapter.search(query: "language", category: "programming", tags: ["ruby"], limit: 10)

      assert_predicate results, :any?
      assert results.all? { |r| r["category"] == "programming" && r["tags"].include?("ruby") }
    end

    def test_search_respects_limit

      results = @adapter.search(query: "programming", limit: 2)

      assert_operator results.length, :<=, 2
    end

    def test_search_returns_empty_array_when_no_matches

      results = @adapter.search(query: "nonexistent term that will never match", limit: 10)

      assert_empty results
    end

    def test_search_handles_empty_query

      results = @adapter.search(query: "", limit: 10)

      # Empty query should return empty array or handle gracefully
      assert_kind_of Array, results
    end

    def test_search_handles_nil_category

      results = @adapter.search(query: "Ruby", category: nil, limit: 10)

      assert_kind_of Array, results
    end

    def test_search_handles_empty_tags_array

      results = @adapter.search(query: "Ruby", tags: [], limit: 10)

      assert_kind_of Array, results
    end

    def test_search_handles_nil_tags

      results = @adapter.search(query: "Ruby", tags: nil, limit: 10)

      assert_kind_of Array, results
    end

    def test_search_orders_by_score_descending

      results = @adapter.search(query: "Ruby", limit: 10)

      return if results.length < 2

      scores = results.map { |r| r["score"] }

      assert_equal scores, scores.sort.reverse
    end

    # ============================================================================
    # Tests for get_chunk(chunk_id:)
    # ============================================================================

    def test_get_chunk_returns_chunk_by_id

      result = @adapter.get_chunk(chunk_id: "doc-1#s0")

      refute_nil result
      assert_equal "doc-1#s0", result["chunk_id"] || result.chunk_id
    end

    def test_get_chunk_returns_nil_for_nonexistent_id

      result = @adapter.get_chunk(chunk_id: "nonexistent-chunk-id")

      assert_nil result
    end

    def test_get_chunk_handles_nil_chunk_id

      result = @adapter.get_chunk(chunk_id: nil)

      assert_nil result
    end

    def test_get_chunk_handles_empty_chunk_id

      result = @adapter.get_chunk(chunk_id: "")

      assert_nil result
    end

    def test_get_chunk_returns_chunk_with_all_fields

      result = @adapter.get_chunk(chunk_id: "doc-1#s0")

      refute_nil result
      assert_equal "doc-1", result["doc_id"] || result.doc_id
      assert_equal "Introduction to Ruby", result["title"] || result.title
      assert_equal "programming", result["category"] || result.category
      assert_equal 0, result["position"] || result.position
    end

    # ============================================================================
    # Tests for list_categories
    # ============================================================================

    def test_list_categories_returns_array_of_strings

      result = @adapter.list_categories

      assert_kind_of Array, result
      assert result.all? { |cat| cat.is_a?(String) }
    end

    def test_list_categories_returns_unique_categories

      result = @adapter.list_categories

      assert_equal result.length, result.uniq.length
    end

    def test_list_categories_includes_all_categories_from_docs

      result = @adapter.list_categories

      assert_includes result, "programming"
      assert_includes result, "frontend"
    end

    def test_list_categories_excludes_nil_categories

      result = @adapter.list_categories

      assert result.none?(&:nil?)
    end

    def test_list_categories_returns_empty_array_when_no_categories

      # Create a fresh database with no categories
      unique_db_path = File.join(Dir.pwd, "db", "kb-adapter-test-empty-#{SecureRandom.uuid}.sqlite")
      FileUtils.mkdir_p(File.dirname(unique_db_path))
      HotwireClub::MCP::Schema.create!(unique_db_path)
      empty_container = HotwireClub::MCP::Database.container(unique_db_path)
      empty_container.relations[:docs].insert(id: "doc-no-cat", title: "No Category")
      empty_adapter = Adapter.new(empty_container)

      result = empty_adapter.list_categories

      assert_empty result

      FileUtils.rm_f(unique_db_path)
    end

    # ============================================================================
    # Tests for list_tags
    # ============================================================================

    def test_list_tags_returns_array

      result = @adapter.list_tags

      assert_kind_of Array, result
    end

    def test_list_tags_returns_all_tags

      result = @adapter.list_tags

      assert_operator result.length, :>=, 6 # We created 6 tags in setup
      assert_includes result, "ruby"
      assert_includes result, "rails"
      assert_includes result, "python"
      assert_includes result, "javascript"
      assert_includes result, "frontend"
      assert_includes result, "backend"
    end

    def test_list_tags_returns_unique_tags

      result = @adapter.list_tags

      assert_equal result.length, result.uniq.length
    end

    def test_list_tags_returns_empty_array_when_no_tags

      # Create a fresh database with no tags
      unique_db_path = File.join(Dir.pwd, "db", "kb-adapter-test-empty-#{SecureRandom.uuid}.sqlite")
      FileUtils.mkdir_p(File.dirname(unique_db_path))
      HotwireClub::MCP::Schema.create!(unique_db_path)
      empty_container = HotwireClub::MCP::Database.container(unique_db_path)
      empty_adapter = Adapter.new(empty_container)

      result = empty_adapter.list_tags

      assert_empty result

      FileUtils.rm_f(unique_db_path)
    end

    # ============================================================================
    # Tests for list_docs(category:, tags:, limit:, offset:)
    # ============================================================================

    def test_list_docs_returns_array_of_docs

      result = @adapter.list_docs

      assert_kind_of Array, result
      assert_predicate result, :any?
    end

    def test_list_docs_returns_all_docs_by_default

      result = @adapter.list_docs

      assert_operator result.length, :>=, 5 # We created 5 docs in setup
    end

    def test_list_docs_filters_by_category

      result = @adapter.list_docs(category: "programming")

      assert_predicate result, :any?
      assert result.all? { |doc| (doc[:category] || doc.category) == "programming" }
    end

    def test_list_docs_filters_by_single_tag

      result = @adapter.list_docs(tags: ["ruby"])

      assert_predicate result, :any?
      doc_ids = result.map { |doc| doc[:id] || doc.id }

      assert_includes doc_ids, "doc-1"
      assert_includes doc_ids, "doc-4"
    end

    def test_list_docs_filters_by_multiple_tags

      result = @adapter.list_docs(tags: ["ruby", "rails"])

      assert_predicate result, :any?
      doc_ids = result.map { |doc| doc[:id] || doc.id }

      assert_includes doc_ids, "doc-4"
      # doc-1 has ruby but not rails, so should not be included
      refute_includes doc_ids, "doc-1"
    end

    def test_list_docs_combines_category_and_tags

      result = @adapter.list_docs(category: "programming", tags: ["ruby"])

      assert_predicate result, :any?
      assert result.all? { |doc| (doc[:category] || doc.category) == "programming" }
      doc_ids = result.map { |doc| doc[:id] || doc.id }

      assert_includes doc_ids, "doc-1"
      assert_includes doc_ids, "doc-4"
    end

    def test_list_docs_respects_limit

      result = @adapter.list_docs(limit: 2)

      assert_operator result.length, :<=, 2
    end

    def test_list_docs_respects_offset

      all_docs = @adapter.list_docs(limit: 100)
      offset_docs = @adapter.list_docs(limit: 100, offset: 1)

      assert_equal all_docs.length - 1, offset_docs.length
      # First doc should be different
      refute_equal all_docs.first[:id] || all_docs.first.id, offset_docs.first[:id] || offset_docs.first.id
    end

    def test_list_docs_handles_nil_category

      result = @adapter.list_docs(category: nil)

      assert_kind_of Array, result
    end

    def test_list_docs_handles_empty_tags_array

      result = @adapter.list_docs(tags: [])

      assert_kind_of Array, result
    end

    def test_list_docs_handles_nil_tags

      result = @adapter.list_docs(tags: nil)

      assert_kind_of Array, result
    end

    def test_list_docs_returns_empty_array_when_no_matches

      result = @adapter.list_docs(category: "nonexistent-category")

      assert_empty result
    end

    def test_list_docs_returns_empty_array_when_no_tags_match

      result = @adapter.list_docs(tags: ["nonexistent-tag"])

      assert_empty result
    end

    def test_list_docs_uses_default_limit

      result = @adapter.list_docs

      # Default limit should be reasonable (e.g., 20)
      assert_operator result.length, :<=, 100 # Sanity check
    end

    def test_list_docs_uses_default_offset

      result = @adapter.list_docs

      # Should start from beginning
      assert_predicate result, :any?
    end

    # ============================================================================
    # Tests for related_docs(doc_id: nil, chunk_id: nil, limit: 5)
    # ============================================================================

    def test_related_docs_returns_array

      result = @adapter.related_docs(doc_id: "doc-1", limit: 5)

      assert_kind_of Array, result
    end

    def test_related_docs_by_doc_id_finds_related_docs

      result = @adapter.related_docs(doc_id: "doc-1", limit: 10)

      # doc-1 has category "programming" and tags ["ruby", "backend"]
      # doc-2 has category "programming" and tags ["python", "backend"] (tag overlap: backend)
      # doc-4 has category "programming" and tags ["ruby", "rails", "backend"] (tag overlap: ruby, backend)
      assert_predicate result, :any?
      doc_ids = result.map { |doc| doc[:id] || doc.id }

      assert_includes doc_ids, "doc-2"
      assert_includes doc_ids, "doc-4"
    end

    def test_related_docs_by_chunk_id_finds_related_docs

      result = @adapter.related_docs(chunk_id: "doc-1#s0", limit: 10)

      # chunk doc-1#s0 belongs to doc-1
      # Should find same related docs as doc-1
      assert_predicate result, :any?
      doc_ids = result.map { |doc| doc[:id] || doc.id }

      assert_includes doc_ids, "doc-2"
      assert_includes doc_ids, "doc-4"
    end

    def test_related_docs_excludes_source_doc

      result = @adapter.related_docs(doc_id: "doc-1", limit: 10)

      doc_ids = result.map { |doc| doc[:id] || doc.id }

      refute_includes doc_ids, "doc-1"
    end

    def test_related_docs_respects_limit

      result = @adapter.related_docs(doc_id: "doc-1", limit: 1)

      assert_operator result.length, :<=, 1
    end

    def test_related_docs_uses_default_limit_when_not_specified

      result = @adapter.related_docs(doc_id: "doc-1")

      assert_operator result.length, :<=, 5 # Default limit is 5
    end

    def test_related_docs_returns_empty_array_when_no_related_docs

      # doc-5 has no category and no tags, so no related docs
      result = @adapter.related_docs(doc_id: "doc-5", limit: 10)

      assert_empty result
    end

    def test_related_docs_handles_nonexistent_doc_id

      result = @adapter.related_docs(doc_id: "nonexistent-doc", limit: 10)

      assert_empty result
    end

    def test_related_docs_handles_nonexistent_chunk_id

      result = @adapter.related_docs(chunk_id: "nonexistent-chunk", limit: 10)

      assert_empty result
    end

    def test_related_docs_handles_nil_doc_id_and_chunk_id

      result = @adapter.related_docs(doc_id: nil, chunk_id: nil, limit: 10)

      assert_empty result
    end

    def test_related_docs_prioritizes_doc_id_over_chunk_id

      # If both are provided, doc_id should be used
      result = @adapter.related_docs(doc_id: "doc-2", chunk_id: "doc-1#s0", limit: 10)

      # Should find docs related to doc-2, not doc-1
      doc_ids = result.map { |doc| doc[:id] || doc.id }
      # doc-2 has category "programming" and tags ["python", "backend"]
      # doc-1 has tags ["ruby", "backend"] (tag overlap: backend)
      # doc-4 has tags ["ruby", "rails", "backend"] (tag overlap: backend)
      assert_includes doc_ids, "doc-1"
      assert_includes doc_ids, "doc-4"
    end

    def test_related_docs_requires_at_least_one_identifier

      # When both are nil, should return empty array
      result = @adapter.related_docs(limit: 10)

      assert_empty result
    end

    def test_related_docs_filters_by_same_category

      result = @adapter.related_docs(doc_id: "doc-1", limit: 10)

      # All related docs should have same category as doc-1 (programming)
      assert result.all? { |doc| (doc[:category] || doc.category) == "programming" }
    end

    def test_related_docs_requires_tag_overlap

      # doc-3 has category "frontend" and tags ["javascript", "frontend"]
      # No other docs have these tags, so no related docs
      result = @adapter.related_docs(doc_id: "doc-3", limit: 10)

      assert_empty result
    end

    # ============================================================================
    # Edge cases and error handling
    # ============================================================================

    def test_all_methods_handle_database_connection_gracefully

      # This test ensures methods don't crash on database errors
      # In a real scenario, you might want to test with a closed/invalid connection
      # For now, we'll just ensure methods return expected types
      result1 = @adapter.search(query: "test", limit: 10)
      result2 = @adapter.get_chunk(chunk_id: "test")
      result3 = @adapter.list_categories
      result4 = @adapter.list_tags
      result5 = @adapter.list_docs
      result6 = @adapter.related_docs(doc_id: "test", limit: 5)

      # Verify all return expected types
      assert_kind_of Array, result1
      assert(result2.nil? || result2.is_a?(Hash))
      assert_kind_of Array, result3
      assert_kind_of Array, result4
      assert_kind_of Array, result5
      assert_kind_of Array, result6
    end

    def test_search_handles_special_characters_in_query

      # Test that special characters don't break the search
      results = @adapter.search(query: "Ruby & Rails", limit: 10)

      assert_kind_of Array, results
    end

    def test_search_handles_sql_injection_attempts

      # Test that SQL injection attempts are handled safely
      malicious_query = "'; DROP TABLE chunks; --"
      results = @adapter.search(query: malicious_query, limit: 10)

      assert_kind_of Array, results
      # Verify table still exists by checking we can still query
      normal_results = @adapter.search(query: "Ruby", limit: 10)

      assert_kind_of Array, normal_results
    end

    def test_get_chunk_handles_sql_injection_attempts

      malicious_id = "'; DROP TABLE chunks; --"
      result = @adapter.get_chunk(chunk_id: malicious_id)

      assert_nil result
      # Verify table still exists
      normal_result = @adapter.get_chunk(chunk_id: "doc-1#s0")

      refute_nil normal_result
    end

    def test_list_docs_handles_sql_injection_in_category

      malicious_category = "'; DROP TABLE docs; --"
      result = @adapter.list_docs(category: malicious_category)

      assert_kind_of Array, result
      # Verify table still exists
      normal_result = @adapter.list_docs(category: "programming")

      assert_kind_of Array, normal_result
    end

    def test_list_docs_handles_sql_injection_in_tags

      malicious_tags = ["'; DROP TABLE docs; --"]
      result = @adapter.list_docs(tags: malicious_tags)

      assert_kind_of Array, result
      # Verify table still exists
      normal_result = @adapter.list_docs(tags: ["ruby"])

      assert_kind_of Array, normal_result
    end

    def test_search_handles_unicode_characters

      # Add a chunk with unicode content
      @container.relations[:chunks].insert(
        chunk_id: "doc-unicode#s0",
        doc_id:   "doc-1",
        title:    "Unicode Test",
        text:     "Ruby é uma linguagem de programação 日本語",
        category: "programming",
        tags:     "ruby",
        position: 10,
      )

      results = @adapter.search(query: "linguagem", limit: 10)

      assert_kind_of Array, results
    end

    def test_search_handles_very_large_limit

      results = @adapter.search(query: "programming", limit: 1_000_000)

      assert_kind_of Array, results
      # Should not return more than actual matches
      assert_operator results.length, :<=, 10 # We only have a few chunks
    end

    def test_list_docs_handles_very_large_limit

      results = @adapter.list_docs(limit: 1_000_000)

      assert_kind_of Array, results
      # Should not return more than actual docs
      assert_operator results.length, :<=, 10 # We only have a few docs
    end

    def test_list_docs_handles_very_large_offset

      results = @adapter.list_docs(limit: 10, offset: 1_000_000)

      assert_empty results
    end

    def test_search_handles_whitespace_only_query

      results = @adapter.search(query: "   ", limit: 10)

      # Should handle gracefully (empty array or all results)
      assert_kind_of Array, results
    end

    def test_parse_tags_handles_whitespace_in_tags_string

      # Test that tags with whitespace are parsed correctly
      # This tests the parse_tags helper function behavior
      tags_string = "ruby, rails, python"
      parsed = parse_tags(tags_string)

      assert_equal ["ruby", "rails", "python"], parsed
    end

    def test_search_results_have_consistent_structure

      results = @adapter.search(query: "Ruby", limit: 10)

      return if results.empty?

      # All results should have the same keys
      first_keys = results.first.keys.sort

      results.each do |result|
        assert_equal first_keys, result.keys.sort, "All results should have consistent structure"
      end
    end

    def test_get_chunk_returns_consistent_structure_with_search

      search_result = @adapter.search(query: "Ruby", limit: 1).first
      return unless search_result

      chunk_result = @adapter.get_chunk(chunk_id: search_result["chunk_id"])

      refute_nil chunk_result
      # Both should have chunk_id
      assert_equal search_result["chunk_id"], chunk_result["chunk_id"] || chunk_result.chunk_id
    end
  end
end
