# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "sqlite3"
require "tempfile"

module HotwireClub
  class TestBuilder < Minitest::Test
    def setup
      @db_path = File.join(Dir.pwd, "db", "kb-test.sqlite3")
      @db_dir = File.dirname(@db_path)
      @temp_dir = Dir.mktmpdir
      @corpus_dir = File.join(@temp_dir, "corpus")
      FileUtils.mkdir_p(@corpus_dir)
    end

    def teardown
      FileUtils.rm_f(@db_path)
      FileUtils.rmdir(@db_dir) if Dir.exist?(@db_dir) && Dir.empty?(@db_dir)
      FileUtils.rm_rf(@temp_dir)
    end

    def test_run_creates_fresh_database
      # Create an existing database file
      FileUtils.mkdir_p(@db_dir)
      File.write(@db_path, "existing database content")

      assert_path_exists @db_path

      create_sample_docs

      HotwireClub::MCP::Builder.run(@corpus_dir, @db_path)

      # Verify the database was recreated (not just deleted)
      assert_path_exists @db_path
      db = SQLite3::Database.new(@db_path)
      # Should be able to query sqlite_master, which means it's a valid SQLite database
      result = db.execute("SELECT name FROM sqlite_master WHERE type='table'")

      refute_nil result
      db.close
    end

    def test_run_loads_docs_into_database
      create_sample_docs

      HotwireClub::MCP::Builder.run(@corpus_dir, @db_path)

      db = SQLite3::Database.new(@db_path)
      docs = db.execute("SELECT id, title, category, summary, body, date FROM docs ORDER BY id")
      db.close

      assert_equal 2, docs.length

      # Verify first doc
      first_doc = docs.find { |d| d[0] == "test-document-one" }

      refute_nil first_doc, "First document should exist"
      assert_equal "test-document-one", first_doc[0]
      assert_equal "Test Document One", first_doc[1]
      assert_equal "Turbo Drive", first_doc[2]
      assert_equal "This is the first test document.", first_doc[3]
      assert_includes first_doc[4], "This is the first test document."
      assert_equal "2023-04-25", first_doc[5]

      # Verify second doc
      second_doc = docs.find { |d| d[0] == "test-document-two" }

      refute_nil second_doc, "Second document should exist"
      assert_equal "test-document-two", second_doc[0]
      assert_equal "Test Document Two", second_doc[1]
      assert_equal "Stimulus", second_doc[2]
      assert_equal "This is the second test document.", second_doc[3]
      assert_includes second_doc[4], "This is the second test document."
      assert_nil second_doc[5]
    end

    def test_run_populates_tags_table
      create_sample_docs

      HotwireClub::MCP::Builder.run(@corpus_dir, @db_path)

      db = SQLite3::Database.new(@db_path)
      tags = db.execute("SELECT name FROM tags ORDER BY name")
      db.close

      # Should have unique tags: rendering, events, caching, actions, controllers
      expected_tags = ["actions", "caching", "controllers", "events", "rendering"]

      assert_equal expected_tags.length, tags.length
      tag_names = tags.map(&:first)

      expected_tags.each do |tag|
        assert_includes tag_names, tag, "Tag '#{tag}' should be in the database"
      end
    end

    def test_run_populates_doc_tags_table
      create_sample_docs

      HotwireClub::MCP::Builder.run(@corpus_dir, @db_path)

      db = SQLite3::Database.new(@db_path)
      doc_tags = db.execute("SELECT doc_id, tag FROM doc_tags ORDER BY doc_id, tag")
      db.close

      # First doc should have: rendering, events, caching
      doc1_tags = doc_tags.select { |dt| dt[0] == "test-document-one" }.map(&:last)

      assert_equal ["caching", "events", "rendering"], doc1_tags.sort

      # Second doc should have: actions, controllers
      doc2_tags = doc_tags.select { |dt| dt[0] == "test-document-two" }.map(&:last)

      assert_equal ["actions", "controllers"], doc2_tags.sort
    end

    def test_run_inserts_tags_with_insert_or_ignore
      create_sample_docs

      # Add a third doc with duplicate tags
      file3 = File.join(@corpus_dir, "doc3.md")
      File.write(file3, <<~MARKDOWN)
        ---
        title: Test Document Three
        category: Turbo Drive
        tags:
          - rendering
          - events
        ready: true
        ---

        This document shares tags with doc1.
      MARKDOWN

      HotwireClub::MCP::Builder.run(@corpus_dir, @db_path)

      db = SQLite3::Database.new(@db_path)
      tags = db.execute("SELECT name FROM tags ORDER BY name")
      db.close

      # Should still have unique tags (no duplicates)
      tag_names = tags.map(&:first)

      assert_equal tag_names.length, tag_names.uniq.length, "Tags should be unique"
    end

    def test_run_creates_chunks_with_comma_joined_tags
      create_sample_docs

      HotwireClub::MCP::Builder.run(@corpus_dir, @db_path)

      db = SQLite3::Database.new(@db_path)
      chunks = db.execute(
        "SELECT chunk_id, doc_id, title, text, category, tags, position FROM chunks ORDER BY doc_id, position",
      )
      db.close

      assert_operator chunks.length, :>=, 2, "Should have at least 2 chunks"

      # Verify chunks have comma-joined tags
      chunks.each do |chunk|
        chunk_id, doc_id, _, text, _, tags, = chunk

        refute_nil chunk_id
        refute_nil doc_id
        refute_nil text
        refute_empty text, "Chunk text should not be empty"
        refute_nil tags, "Chunk should have tags"

        # Tags should be comma-joined (order-insensitive)
        if doc_id == "test-document-one"
          expected_tags = ["caching", "events", "rendering"]
          actual_tags = tags.split(",").map(&:strip).sort

          assert_equal expected_tags.sort, actual_tags, "First doc chunks should have correct comma-joined tags"
        elsif doc_id == "test-document-two"
          expected_tags = ["actions", "controllers"]
          actual_tags = tags.split(",").map(&:strip).sort

          assert_equal expected_tags.sort, actual_tags, "Second doc chunks should have correct comma-joined tags"
        end
      end
    end

    def test_run_creates_non_empty_chunks
      create_sample_docs

      HotwireClub::MCP::Builder.run(@corpus_dir, @db_path)

      db = SQLite3::Database.new(@db_path)
      chunks = db.execute("SELECT text FROM chunks")
      db.close

      assert_operator chunks.length, :>=, 2, "Should have at least 2 chunks"

      chunks.each do |chunk|
        text = chunk.first

        refute_nil text
        refute_empty text.strip, "Chunk text should not be empty"
      end
    end

    def test_run_fts_search_returns_expected_doc
      create_sample_docs

      HotwireClub::MCP::Builder.run(@corpus_dir, @db_path)

      db = SQLite3::Database.new(@db_path)

      # Search for content from first document
      results = db.execute("SELECT * FROM chunks WHERE chunks MATCH 'first' ORDER BY position")
      db.close

      assert_operator results.length, :>=, 1, "FTS search should return at least one result"
      # Verify the results contain content from the first document
      doc_ids = results.map { |r| r[1] } # doc_id is second column

      assert_includes doc_ids, "test-document-one", "FTS search should return chunks from first document"
    end

    def test_run_fts_search_returns_chunks_by_category
      create_sample_docs

      HotwireClub::MCP::Builder.run(@corpus_dir, @db_path)

      db = SQLite3::Database.new(@db_path)

      # Search for content that should be in Turbo Drive category
      results = db.execute("SELECT * FROM chunks WHERE chunks MATCH 'Turbo' ORDER BY position")
      db.close

      assert_operator results.length, :>=, 1, "FTS search should return at least one result"
      # Verify the results contain chunks from Turbo Drive category
      categories = results.map { |r| r[4] } # category is fifth column

      assert_includes categories, "Turbo Drive", "FTS search should return chunks with Turbo Drive category"
    end

    def test_run_inserts_all_data_in_single_transaction
      create_sample_docs

      HotwireClub::MCP::Builder.run(@corpus_dir, @db_path)

      db = SQLite3::Database.new(@db_path)

      # Count records in each table
      doc_count = db.execute("SELECT COUNT(*) FROM docs").first.first
      tag_count = db.execute("SELECT COUNT(*) FROM tags").first.first
      doc_tag_count = db.execute("SELECT COUNT(*) FROM doc_tags").first.first
      chunk_count = db.execute("SELECT COUNT(*) FROM chunks").first.first

      db.close

      # Verify all data is present (transaction succeeded)
      assert_equal 2, doc_count, "Should have 2 docs"
      assert_operator tag_count, :>=, 5, "Should have at least 5 tags"
      assert_operator doc_tag_count, :>=, 5, "Should have at least 5 doc_tags"
      assert_operator chunk_count, :>=, 2, "Should have at least 2 chunks"
    end

    def test_run_handles_empty_corpus_directory
      # Don't create any docs

      HotwireClub::MCP::Builder.run(@corpus_dir, @db_path)

      db = SQLite3::Database.new(@db_path)
      doc_count = db.execute("SELECT COUNT(*) FROM docs").first.first
      chunk_count = db.execute("SELECT COUNT(*) FROM chunks").first.first
      db.close

      assert_equal 0, doc_count, "Should have 0 docs"
      assert_equal 0, chunk_count, "Should have 0 chunks"
    end

    private

    def create_sample_docs
      # Create first document
      file1 = File.join(@corpus_dir, "doc1.md")
      File.write(file1, <<~MARKDOWN)
        ---
        title: Test Document One
        date: 2023-04-25
        categories:
          - Turbo Drive
        tags:
          - rendering
          - events
          - caching
        description: This is the first test document.
        ready: true
        ---

        ## Overview

        This is the first test document.

        ## Implementation

        This is the implementation section.
      MARKDOWN

      # Create second document
      file2 = File.join(@corpus_dir, "doc2.md")
      File.write(file2, <<~MARKDOWN)
        ---
        title: Test Document Two
        categories:
          - Stimulus
        tags:
          - actions
          - controllers
        description: This is the second test document.
        ready: true
        ---

        ## Overview

        This is the second test document.

        ## Usage

        This is the usage section.
      MARKDOWN
    end
  end
end
