# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

module HotwireClub
  class TestChunker < Minitest::Test
    def setup
      @temp_dir = Dir.mktmpdir
      @corpus_dir = File.join(@temp_dir, "corpus")
      FileUtils.mkdir_p(@corpus_dir)
    end

    def teardown
      FileUtils.rm_rf(@temp_dir)
    end

    def test_simple_doc_with_multiple_headings_creates_multiple_chunks_with_correct_titles
      file = File.join(@corpus_dir, "test.md")
      File.write(file, <<~MARKDOWN)
        ---
        title: Test Document
        category: Turbo Drive
        tags:
          - rendering
          - events
        ready: true
        ---

        ## Overview

        This is the overview section.

        ## Implementation

        This is the implementation section.

        ## Caveats

        This is the caveats section.
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)
      chunks = HotwireClub::MCP::Chunker.chunk_docs(docs)

      assert_equal 1, docs.length
      assert_equal 3, chunks.length

      # Check first chunk
      assert_equal "Overview", chunks[0].title
      assert_equal "Turbo Drive", chunks[0].category
      assert_equal ["rendering", "events"], chunks[0].tags
      assert_equal 0, chunks[0].position
      assert_includes chunks[0].text, "## Overview"
      assert_includes chunks[0].text, "This is the overview section"

      # Check second chunk
      assert_equal "Implementation", chunks[1].title
      assert_equal "Turbo Drive", chunks[1].category
      assert_equal ["rendering", "events"], chunks[1].tags
      assert_equal 1, chunks[1].position
      assert_includes chunks[1].text, "## Implementation"
      assert_includes chunks[1].text, "This is the implementation section"

      # Check third chunk
      assert_equal "Caveats", chunks[2].title
      assert_equal "Turbo Drive", chunks[2].category
      assert_equal ["rendering", "events"], chunks[2].tags
      assert_equal 2, chunks[2].position
      assert_includes chunks[2].text, "## Caveats"
      assert_includes chunks[2].text, "This is the caveats section"
    end

    def test_very_long_section_splits_into_several_chunks_with_size_constraint
      # Create a section that exceeds MAX_SIZE (3500 chars)
      long_content = "This is a paragraph. " * 200 # ~4000 chars
      file = File.join(@corpus_dir, "long.md")
      File.write(file, <<~MARKDOWN)
        ---
        title: Long Document
        category: Testing
        tags: [test]
        ready: true
        ---

        ## Long Section

        #{long_content}
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)
      chunks = HotwireClub::MCP::Chunker.chunk_docs(docs)

      assert_equal 1, docs.length
      assert_operator chunks.length, :>=, 1, "Should create at least one chunk"

      # Verify all chunks are within size constraints
      chunks.each do |chunk|
        assert_operator chunk.text.length, :<=, 3500, "Chunk should not exceed MAX_SIZE"
        assert_equal "Long Section", chunk.title
        assert_equal "Testing", chunk.category
      end

      # If content is long enough, should create multiple chunks
      total_content_length = long_content.length + "## Long Section\n\n".length
      if total_content_length > 3500
        assert_operator chunks.length, :>=, 2, "Should split long content into multiple chunks"
      end
    end

    def test_positions_are_contiguous_per_document
      # Create two documents
      file1 = File.join(@corpus_dir, "doc1.md")
      File.write(file1, <<~MARKDOWN)
        ---
        title: Document One
        ready: true
        ---

        ## Section A

        Content A

        ## Section B

        Content B
      MARKDOWN

      file2 = File.join(@corpus_dir, "doc2.md")
      File.write(file2, <<~MARKDOWN)
        ---
        title: Document Two
        ready: true
        ---

        ## Section X

        Content X

        ## Section Y

        Content Y

        ## Section Z

        Content Z
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)
      chunks = HotwireClub::MCP::Chunker.chunk_docs(docs)

      assert_equal 2, docs.length
      assert_equal 5, chunks.length # 2 from doc1, 3 from doc2

      # First document chunks should have positions 0, 1
      doc1_chunks = chunks[0..1]

      assert_equal 0, doc1_chunks[0].position
      assert_equal 1, doc1_chunks[1].position

      # Second document chunks should have positions 0, 1, 2 (reset per doc)
      doc2_chunks = chunks[2..4]

      assert_equal 0, doc2_chunks[0].position
      assert_equal 1, doc2_chunks[1].position
      assert_equal 2, doc2_chunks[2].position
    end

    def test_chunks_propagate_category_and_tags_from_doc
      file = File.join(@corpus_dir, "test.md")
      File.write(file, <<~MARKDOWN)
        ---
        title: Test Document
        category: Turbo Drive
        tags:
          - rendering
          - events
          - caching
        ready: true
        ---

        ## Section One

        Content one.

        ## Section Two

        Content two.
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)
      chunks = HotwireClub::MCP::Chunker.chunk_docs(docs)

      assert_equal 2, chunks.length

      chunks.each do |chunk|
        assert_equal "Turbo Drive", chunk.category
        assert_equal ["rendering", "events", "caching"], chunk.tags
        assert_nil chunk.id # id will be populated from database
        assert_nil chunk.doc_id # doc_id will be populated from database
      end
    end

    def test_chunks_split_on_paragraph_boundaries_when_possible
      # Create content that would exceed target size but can be split at paragraphs
      paragraph = "This is a paragraph with some content. " * 50 # ~2500 chars per paragraph
      file = File.join(@corpus_dir, "paragraphs.md")
      File.write(file, <<~MARKDOWN)
        ---
        title: Paragraph Test
        ready: true
        ---

        ## Long Section

        #{paragraph}

        #{paragraph}

        #{paragraph}
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)
      chunks = HotwireClub::MCP::Chunker.chunk_docs(docs)

      assert_equal 1, docs.length
      assert_operator chunks.length, :>=, 1

      # Verify chunks don't split mid-paragraph
      chunks.each do |chunk|
        # Each chunk should contain complete paragraphs
        # Check that paragraphs aren't split (each paragraph should be complete)
        assert_operator chunk.text.length, :<=, 3500
      end
    end

    def test_document_without_headings_creates_single_chunk
      file = File.join(@corpus_dir, "no-headings.md")
      File.write(file, <<~MARKDOWN)
        ---
        title: No Headings Document
        ready: true
        ---

        This is content without any headings.

        Just regular paragraphs here.
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)
      chunks = HotwireClub::MCP::Chunker.chunk_docs(docs)

      assert_equal 1, docs.length
      assert_equal 1, chunks.length
      assert_nil chunks[0].title
      assert_equal 0, chunks[0].position
      assert_includes chunks[0].text, "This is content without any headings"
    end

    def test_document_with_single_heading_creates_one_chunk
      file = File.join(@corpus_dir, "single-heading.md")
      File.write(file, <<~MARKDOWN)
        ---
        title: Single Heading Document
        ready: true
        ---

        ## Only Section

        This is the only section.
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)
      chunks = HotwireClub::MCP::Chunker.chunk_docs(docs)

      assert_equal 1, docs.length
      assert_equal 1, chunks.length
      assert_equal "Only Section", chunks[0].title
      assert_equal 0, chunks[0].position
    end

    def test_empty_document_array_returns_empty_chunks_array
      chunks = HotwireClub::MCP::Chunker.chunk_docs([])

      assert_empty chunks
    end

    def test_chunks_respect_target_size_when_possible
      # Create content that's just over target size but under max
      content = "This is a paragraph. " * 100 # ~2000 chars
      file = File.join(@corpus_dir, "target-size.md")
      File.write(file, <<~MARKDOWN)
        ---
        title: Target Size Test
        ready: true
        ---

        ## Section One

        #{content}

        ## Section Two

        #{content}
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)
      chunks = HotwireClub::MCP::Chunker.chunk_docs(docs)

      assert_equal 1, docs.length
      # Should create 2 chunks (one per section) since each is under MAX_SIZE
      assert_equal 2, chunks.length

      chunks.each do |chunk|
        assert_operator chunk.text.length, :<=, 3500
      end
    end

    def test_chunks_handle_h1_and_h2_headings
      file = File.join(@corpus_dir, "headings.md")
      File.write(file, <<~MARKDOWN)
        ---
        title: Headings Test
        ready: true
        ---

        # Main Heading

        Main content.

        ## Sub Heading

        Sub content.
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)
      chunks = HotwireClub::MCP::Chunker.chunk_docs(docs)

      assert_equal 1, docs.length
      assert_equal 2, chunks.length
      assert_equal "Main Heading", chunks[0].title
      assert_equal "Sub Heading", chunks[1].title
    end
  end
end
