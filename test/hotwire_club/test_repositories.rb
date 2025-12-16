# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "rom"
require "securerandom"

module HotwireClub
  # Tests for DocsRepo
  class TestDocsRepo < Minitest::Test
    def setup
      # Use unique database path with UUID to ensure complete isolation
      @db_path = File.join(Dir.pwd, "db", "kb-repositories-docs-test-#{SecureRandom.uuid}.sqlite")
      @db_dir = File.dirname(@db_path)
      FileUtils.mkdir_p(@db_dir)
      FileUtils.rm_f(@db_path)
      HotwireClub::MCP::Schema.create!(@db_path)
      @container = HotwireClub::MCP::Database.container(@db_path)
      setup_test_data
      @repo = DocsRepo.new(@container)
    end

    def teardown
      # Clear container reference to allow garbage collection
      @container = nil
      @repo = nil
      FileUtils.rm_f(@db_path)
      FileUtils.rmdir(@db_dir) if Dir.exist?(@db_dir) && Dir.empty?(@db_dir)
    end

    def setup_test_data
      @container.relations[:docs].insert(id: "doc-1", title: "Doc 1", category: "cat1")
      @container.relations[:docs].insert(id: "doc-2", title: "Doc 2", category: "cat1")
      @container.relations[:docs].insert(id: "doc-3", title: "Doc 3", category: "cat2")
      @container.relations[:tags].insert(name: "tag1")
      @container.relations[:tags].insert(name: "tag2")
      @container.relations[:doc_tags].insert(doc_id: "doc-1", tag: "tag1")
      @container.relations[:doc_tags].insert(doc_id: "doc-1", tag: "tag2")
      @container.relations[:doc_tags].insert(doc_id: "doc-2", tag: "tag1")
      @container.relations[:chunks].insert(
        chunk_id: "chunk-1",
        doc_id:   "doc-1",
        title:    "Chunk 1",
        text:     "Text",
        position: 0,
      )
    end

    def test_all_returns_all_docs
      result = @repo.all

      assert_equal 3, result.length
      assert result.all? { |doc| doc.is_a?(ROM::Struct::Doc) || doc.is_a?(Hash) }
    end

    def test_by_id_returns_single_doc
      result = @repo.by_id("doc-1")

      assert_equal "doc-1", result[:id] || result.id
      assert_equal "Doc 1", result[:title] || result.title
    end

    def test_by_id_returns_nil_for_nonexistent_id
      result = @repo.by_id("nonexistent")

      assert_nil result
    end

    def test_list_returns_all_docs_by_default
      result = @repo.list

      assert_equal 3, result.length
    end

    def test_list_filters_by_category
      result = @repo.list(category: "cat1")

      assert_equal 2, result.length
      assert result.all? { |doc| (doc[:category] || doc.category) == "cat1" }
    end

    def test_list_filters_by_tags
      result = @repo.list(tags: ["tag1"])

      assert_equal 2, result.length
      doc_ids = result.map { |doc| doc[:id] || doc.id }.sort

      assert_equal ["doc-1", "doc-2"], doc_ids
    end

    def test_list_filters_by_multiple_tags
      result = @repo.list(tags: ["tag1", "tag2"])

      assert_equal 1, result.length
      assert_equal "doc-1", result.first[:id] || result.first.id
    end

    def test_list_respects_limit
      result = @repo.list(limit: 2)

      assert_equal 2, result.length
    end

    def test_list_respects_offset
      result = @repo.list(limit: 2, offset: 1)

      assert_equal 2, result.length
      # Should skip first doc
      first_id = result.first[:id] || result.first.id

      refute_equal "doc-1", first_id
    end

    def test_list_combines_category_and_tags
      result = @repo.list(category: "cat1", tags: ["tag1"])

      assert_equal 2, result.length
      assert result.all? { |doc| (doc[:category] || doc.category) == "cat1" }
    end

    def test_categories_returns_unique_categories
      result = @repo.categories

      assert_equal 2, result.length
      assert_includes result, "cat1"
      assert_includes result, "cat2"
    end

    def test_related_docs_by_doc_id_same_category_and_tag_overlap
      # doc-1 has tags: tag1, tag2, category: cat1
      # doc-2 has tags: tag1, category: cat1 (should match)
      # doc-3 has tags: none, category: cat2 (should not match)
      result = @repo.related_docs(doc_id: "doc-1", limit: 10)

      assert_equal 1, result.length
      assert_equal "doc-2", result.first[:id] || result.first.id
    end

    def test_related_docs_by_chunk_id
      # chunk-1 belongs to doc-1
      # doc-1 has tags: tag1, tag2, category: cat1
      # doc-2 has tags: tag1, category: cat1 (should match)
      result = @repo.related_docs(chunk_id: "chunk-1", limit: 10)

      assert_equal 1, result.length
      assert_equal "doc-2", result.first[:id] || result.first.id
    end

    def test_related_docs_respects_limit
      # Add more related docs
      @container.relations[:docs].insert(id: "doc-4", title: "Doc 4", category: "cat1")
      @container.relations[:doc_tags].insert(doc_id: "doc-4", tag: "tag1")

      result = @repo.related_docs(doc_id: "doc-1", limit: 1)

      assert_equal 1, result.length
    end

    def test_related_docs_excludes_self_when_by_doc_id
      # doc-1 should not appear in related docs for itself
      result = @repo.related_docs(doc_id: "doc-1", limit: 10)

      assert result.none? { |doc| (doc[:id] || doc.id) == "doc-1" }
    end
  end

  # Tests for TagsRepo
  class TestTagsRepo < Minitest::Test
    def setup
      # Use unique database path with UUID to ensure complete isolation
      @db_path = File.join(Dir.pwd, "db", "kb-repositories-tags-test-#{SecureRandom.uuid}.sqlite")
      @db_dir = File.dirname(@db_path)
      FileUtils.mkdir_p(@db_dir)
      FileUtils.rm_f(@db_path)
      HotwireClub::MCP::Schema.create!(@db_path)
      @container = HotwireClub::MCP::Database.container(@db_path)
      setup_test_data
      @repo = TagsRepo.new(@container)
    end

    def teardown
      # Clear container reference to allow garbage collection
      @container = nil
      @repo = nil
      FileUtils.rm_f(@db_path)
      FileUtils.rmdir(@db_dir) if Dir.exist?(@db_dir) && Dir.empty?(@db_dir)
    end

    def setup_test_data
      # Ensure data is inserted and committed
      @container.relations[:tags].insert(name: "ruby")
      @container.relations[:tags].insert(name: "rails")
      @container.relations[:tags].insert(name: "hotwire")
      @container.relations[:docs].insert(id: "doc-1", title: "Doc 1")
      @container.relations[:docs].insert(id: "doc-2", title: "Doc 2")
      @container.relations[:doc_tags].insert(doc_id: "doc-1", tag: "ruby")
      @container.relations[:doc_tags].insert(doc_id: "doc-1", tag: "rails")
      @container.relations[:doc_tags].insert(doc_id: "doc-2", tag: "ruby")
      # hotwire has 0 docs
    end

    def find_tag_by_name(tags, name)
      tags.find { |tag| tag_name(tag) == name }
    end

    def tag_name(tag)
      tag[:name] || tag.name
    end

    def tag_count(tag)
      tag[:count] || tag.count
    end

    def test_all_with_counts_returns_tags_with_doc_counts
      result = @repo.all_with_counts

      assert_equal 3, result.length

      ruby_tag = find_tag_by_name(result, "ruby")
      rails_tag = find_tag_by_name(result, "rails")
      hotwire_tag = find_tag_by_name(result, "hotwire")

      assert_equal 2, tag_count(ruby_tag)
      assert_equal 1, tag_count(rails_tag)
      assert_equal 0, tag_count(hotwire_tag)
    end

    def test_all_with_counts_includes_tag_name
      result = @repo.all_with_counts

      assert result.all? { |tag| tag_name(tag).is_a?(String) }
    end

    def test_all_with_counts_returns_empty_array_when_no_tags
      # Use a unique database path for this test to avoid interference
      # Create in a separate directory to ensure complete isolation
      unique_dir = File.join(Dir.pwd, "db", "test-isolation-#{SecureRandom.uuid}")
      FileUtils.mkdir_p(unique_dir)
      unique_db_path = File.join(unique_dir, "empty-test.sqlite")

      HotwireClub::MCP::Schema.create!(unique_db_path)
      # Create a completely fresh container for this test
      fresh_container = HotwireClub::MCP::Database.container(unique_db_path)
      fresh_repo = TagsRepo.new(fresh_container)

      result = fresh_repo.all_with_counts

      assert_empty result

      # Cleanup
      FileUtils.rm_f(unique_db_path)
      FileUtils.rmdir(unique_dir) if Dir.exist?(unique_dir) && Dir.empty?(unique_dir)
    end
  end

  # Tests for ChunksRepo
  class TestChunksRepo < Minitest::Test
    def setup
      # Use unique database path with UUID to ensure complete isolation
      @db_path = File.join(Dir.pwd, "db", "kb-repositories-chunks-test-#{SecureRandom.uuid}.sqlite")
      @db_dir = File.dirname(@db_path)
      FileUtils.mkdir_p(@db_dir)
      FileUtils.rm_f(@db_path)
      HotwireClub::MCP::Schema.create!(@db_path)
      @container = HotwireClub::MCP::Database.container(@db_path)
      setup_test_data
      @repo = ChunksRepo.new(@container)
    end

    def teardown
      # Clear container reference to allow garbage collection
      @container = nil
      @repo = nil
      FileUtils.rm_f(@db_path)
      FileUtils.rmdir(@db_dir) if Dir.exist?(@db_dir) && Dir.empty?(@db_dir)
    end

    def setup_test_data
      @container.relations[:chunks].insert(
        chunk_id: "chunk-1",
        doc_id:   "doc-1",
        title:    "Ruby Programming",
        text:     "Ruby is a dynamic programming language",
        category: "programming",
        tags:     "ruby",
        position: 0,
      )
      @container.relations[:chunks].insert(
        chunk_id: "chunk-2",
        doc_id:   "doc-2",
        title:    "Python Programming",
        text:     "Python is also a dynamic language",
        category: "programming",
        tags:     "python",
        position: 0,
      )
      @container.relations[:chunks].insert(
        chunk_id: "chunk-3",
        doc_id:   "doc-3",
        title:    "JavaScript Basics",
        text:     "JavaScript is a scripting language",
        category: "frontend",
        tags:     "javascript",
        position: 0,
      )
    end

    def test_by_id_returns_single_chunk
      result = @repo.by_id("chunk-1")

      assert_equal "chunk-1", result[:chunk_id] || result.chunk_id
      assert_equal "Ruby Programming", result[:title] || result.title
    end

    def test_by_id_returns_nil_for_nonexistent_id
      result = @repo.by_id("nonexistent")

      assert_nil result
    end

    def test_search_finds_chunks_by_text
      result = @repo.search(query: "Ruby")

      assert_equal 1, result.length
      assert_equal "chunk-1", result.first[:chunk_id] || result.first.chunk_id
    end

    def test_search_finds_chunks_by_title
      result = @repo.search(query: "Python")

      assert_equal 1, result.length
      assert_equal "chunk-2", result.first[:chunk_id] || result.first.chunk_id
    end

    def test_search_filters_by_category
      result = @repo.search(query: "language", category: "programming")

      assert_equal 2, result.length
      assert result.all? { |chunk| (chunk[:category] || chunk.category) == "programming" }
    end

    def test_search_filters_by_single_tag
      result = @repo.search(query: "language", tags: ["ruby"])

      assert_equal 1, result.length
      assert_equal "chunk-1", result.first[:chunk_id] || result.first.chunk_id
    end

    def test_search_filters_by_multiple_tags
      # Add a chunk with both tags
      @container.relations[:chunks].insert(
        chunk_id: "chunk-4",
        doc_id:   "doc-4",
        title:    "Multi Tag",
        text:     "This has multiple tags",
        category: "programming",
        tags:     "ruby,python",
        position: 0,
      )

      result = @repo.search(query: "tags", tags: ["ruby", "python"])

      assert_equal 1, result.length
      assert_equal "chunk-4", result.first[:chunk_id] || result.first.chunk_id
    end

    def test_search_combines_category_and_tags
      result = @repo.search(query: "language", category: "programming", tags: ["ruby"])

      assert_equal 1, result.length
      assert_equal "chunk-1", result.first[:chunk_id] || result.first.chunk_id
    end

    def test_search_respects_limit
      result = @repo.search(query: "language", limit: 1)

      assert_equal 1, result.length
    end

    def test_search_returns_empty_array_when_no_matches
      result = @repo.search(query: "nonexistent term")

      assert_empty result
    end

    def test_search_handles_empty_query
      result = @repo.search(query: "")

      # Empty query might return all or none, depending on implementation
      # This test documents the expected behavior
      assert_kind_of Array, result
    end
  end
end
