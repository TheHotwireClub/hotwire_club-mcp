# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "rom"

module HotwireClub
  class TestRelations < Minitest::Test
    def setup
      @db_path = File.join(Dir.pwd, "db", "kb-relations-test.sqlite")
      @db_dir = File.dirname(@db_path)
      FileUtils.mkdir_p(@db_dir)
      HotwireClub::MCP::Schema.create!(@db_path)
      @container = HotwireClub::MCP::Database.container(@db_path)
    end

    def teardown
      FileUtils.rm_f(@db_path)
      FileUtils.rmdir(@db_dir) if Dir.exist?(@db_dir) && Dir.empty?(@db_dir)
    end

    # Tests for Docs relation
    def test_docs_relation_exists
      assert @container.relations.key?(:docs), "docs relation should be registered"
      assert_kind_of ROM::Relation, @container.relations[:docs]
    end

    def test_docs_relation_can_insert_and_select
      docs_relation = @container.relations[:docs]

      docs_relation.insert(
        id:       "test-doc-1",
        title:    "Test Document",
        category: "testing",
        summary:  "A test document",
        body:     "This is the body",
        date:     "2024-01-01",
      )

      result = docs_relation.to_a

      assert_equal 1, result.length
      assert_equal "test-doc-1", result.first[:id]
      assert_equal "Test Document", result.first[:title]
      assert_equal "testing", result.first[:category]
    end

    def test_docs_relation_supports_optional_fields
      docs_relation = @container.relations[:docs]

      docs_relation.insert(
        id:    "test-doc-2",
        title: "Minimal Document",
      )

      result = docs_relation.where(id: "test-doc-2").to_a

      assert_equal 1, result.length
      assert_equal "test-doc-2", result.first[:id]
      assert_equal "Minimal Document", result.first[:title]
      assert_nil result.first[:category]
    end

    # Tests for Tags relation
    def test_tags_relation_exists
      assert @container.relations.key?(:tags), "tags relation should be registered"
      assert_kind_of ROM::Relation, @container.relations[:tags]
    end

    def test_tags_relation_can_insert_and_select
      tags_relation = @container.relations[:tags]

      tags_relation.insert(name: "ruby")
      tags_relation.insert(name: "rails")

      result = tags_relation.to_a

      assert_equal 2, result.length
      tag_names = result.map { |r| r[:name] }.sort

      assert_equal ["rails", "ruby"], tag_names
    end

    def test_tags_relation_primary_key_is_name
      tags_relation = @container.relations[:tags]

      tags_relation.insert(name: "javascript")

      # Try to insert duplicate (should fail)
      assert_raises(Sequel::UniqueConstraintViolation) do
        tags_relation.insert(name: "javascript")
      end
    end

    # Tests for DocTags relation
    def test_doc_tags_relation_exists
      assert @container.relations.key?(:doc_tags), "doc_tags relation should be registered"
      assert_kind_of ROM::Relation, @container.relations[:doc_tags]
    end

    def test_doc_tags_relation_can_insert_and_select
      # First create a doc and tags
      @container.relations[:docs].insert(id: "doc-1", title: "Doc 1")
      @container.relations[:tags].insert(name: "tag1")
      @container.relations[:tags].insert(name: "tag2")

      doc_tags_relation = @container.relations[:doc_tags]

      doc_tags_relation.insert(doc_id: "doc-1", tag: "tag1")
      doc_tags_relation.insert(doc_id: "doc-1", tag: "tag2")

      result = doc_tags_relation.where(doc_id: "doc-1").to_a

      assert_equal 2, result.length
      tags = result.map { |r| r[:tag] }.sort

      assert_equal ["tag1", "tag2"], tags
    end

    def test_doc_tags_relation_composite_primary_key
      @container.relations[:docs].insert(id: "doc-2", title: "Doc 2")
      @container.relations[:tags].insert(name: "tag3")

      doc_tags_relation = @container.relations[:doc_tags]

      doc_tags_relation.insert(doc_id: "doc-2", tag: "tag3")

      # Try to insert duplicate (should fail)
      assert_raises(Sequel::UniqueConstraintViolation) do
        doc_tags_relation.insert(doc_id: "doc-2", tag: "tag3")
      end
    end

    # Tests for Chunks relation
    def test_chunks_relation_exists
      assert @container.relations.key?(:chunks), "chunks relation should be registered"
      assert_kind_of ROM::Relation, @container.relations[:chunks]
    end

    def test_chunks_relation_can_insert_and_select
      chunks_relation = @container.relations[:chunks]

      chunks_relation.insert(
        chunk_id: "chunk-1",
        doc_id:   "doc-1",
        title:    "Chunk Title",
        text:     "This is chunk text",
        category: "testing",
        tags:     "tag1,tag2",
        position: 1,
      )

      result = chunks_relation.to_a

      assert_equal 1, result.length
      assert_equal "chunk-1", result.first[:chunk_id]
      assert_equal "doc-1", result.first[:doc_id]
      assert_equal "Chunk Title", result.first[:title]
      assert_equal "This is chunk text", result.first[:text]
      assert_equal 1, result.first[:position]
    end

    def test_chunks_relation_supports_optional_fields
      chunks_relation = @container.relations[:chunks]

      chunks_relation.insert(
        chunk_id: "chunk-2",
        doc_id:   "doc-2",
        title:    "Minimal Chunk",
        text:     "Text content",
        position: 0,
      )

      result = chunks_relation.where(chunk_id: "chunk-2").to_a

      assert_equal 1, result.length
      assert_equal "chunk-2", result.first[:chunk_id]
      assert_nil result.first[:category]
      assert_nil result.first[:tags]
    end

    def test_chunks_relation_schema_is_explicitly_defined
      chunks_relation = @container.relations[:chunks]

      # Verify that the schema attributes match what's expected
      # This tests that infer: false was used and schema is explicit
      schema = chunks_relation.schema

      # Check that required attributes exist
      assert schema[:chunk_id], "chunk_id should be in schema"
      assert schema[:doc_id], "doc_id should be in schema"
      assert schema[:title], "title should be in schema"
      assert schema[:text], "text should be in schema"
      assert schema[:position], "position should be in schema"

      # Check optional attributes
      assert schema[:category], "category should be in schema"
      assert schema[:tags], "tags should be in schema"
    end

    def test_chunks_relation_supports_fts5_search
      chunks_relation = @container.relations[:chunks]

      chunks_relation.insert(
        chunk_id: "chunk-search-1",
        doc_id:   "doc-search",
        title:    "Ruby Programming",
        text:     "Ruby is a dynamic programming language",
        position: 0,
      )

      chunks_relation.insert(
        chunk_id: "chunk-search-2",
        doc_id:   "doc-search",
        title:    "Python Programming",
        text:     "Python is also a dynamic language",
        position: 1,
      )

      # FTS5 search should work - use full_text_search method
      result = chunks_relation.full_text_search("Ruby").to_a

      assert_equal 1, result.length
      assert_equal "chunk-search-1", result.first[:chunk_id]
    end
  end
end
