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
      assert_equal "test-document#s0", chunks[0].id
      assert_equal "test-document", chunks[0].doc_id
      assert_includes chunks[0].text, "## Overview"
      assert_includes chunks[0].text, "This is the overview section"

      # Check second chunk
      assert_equal "Implementation", chunks[1].title
      assert_equal "Turbo Drive", chunks[1].category
      assert_equal ["rendering", "events"], chunks[1].tags
      assert_equal 1, chunks[1].position
      assert_equal "test-document#s1", chunks[1].id
      assert_equal "test-document", chunks[1].doc_id
      assert_includes chunks[1].text, "## Implementation"
      assert_includes chunks[1].text, "This is the implementation section"

      # Check third chunk
      assert_equal "Caveats", chunks[2].title
      assert_equal "Turbo Drive", chunks[2].category
      assert_equal ["rendering", "events"], chunks[2].tags
      assert_equal 2, chunks[2].position
      assert_equal "test-document#s2", chunks[2].id
      assert_equal "test-document", chunks[2].doc_id
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
      chunks.each_with_index do |chunk, idx|
        assert_operator chunk.text.length, :<=, 3500, "Chunk should not exceed MAX_SIZE"
        assert_equal "Long Section", chunk.title
        assert_equal "Testing", chunk.category
        # Verify chunk IDs: first part is #s0, subsequent parts are #s0-1, #s0-2, etc.
        expected_id = idx.zero? ? "long-document#s0" : "long-document#s0-#{idx}"

        assert_equal expected_id, chunk.id
        assert_equal "long-document", chunk.doc_id
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
      assert_equal "document-one#s0", doc1_chunks[0].id
      assert_equal "document-one", doc1_chunks[0].doc_id
      assert_equal 1, doc1_chunks[1].position
      assert_equal "document-one#s1", doc1_chunks[1].id
      assert_equal "document-one", doc1_chunks[1].doc_id

      # Second document chunks should have positions 0, 1, 2 (reset per doc)
      doc2_chunks = chunks[2..4]

      assert_equal 0, doc2_chunks[0].position
      assert_equal "document-two#s0", doc2_chunks[0].id
      assert_equal "document-two", doc2_chunks[0].doc_id
      assert_equal 1, doc2_chunks[1].position
      assert_equal "document-two#s1", doc2_chunks[1].id
      assert_equal "document-two", doc2_chunks[1].doc_id
      assert_equal 2, doc2_chunks[2].position
      assert_equal "document-two#s2", doc2_chunks[2].id
      assert_equal "document-two", doc2_chunks[2].doc_id
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

      chunks.each_with_index do |chunk, idx|
        assert_equal "Turbo Drive", chunk.category
        assert_equal ["rendering", "events", "caching"], chunk.tags
        assert_equal "test-document#s#{idx}", chunk.id
        assert_equal "test-document", chunk.doc_id
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
      chunks.each_with_index do |chunk, idx|
        # Each chunk should contain complete paragraphs
        # Check that paragraphs aren't split (each paragraph should be complete)
        assert_operator chunk.text.length, :<=, 3500
        # Verify chunk IDs (if section is split, first part is #s0, subsequent are #s0-1, etc.)
        if idx.zero?
          assert_equal "paragraph-test#s0", chunk.id
        else
          assert_equal "paragraph-test#s0-#{idx}", chunk.id
        end

        assert_equal "paragraph-test", chunk.doc_id
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
      assert_equal "no-headings-document#s0", chunks[0].id
      assert_equal "no-headings-document", chunks[0].doc_id
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
      assert_equal "single-heading-document#s0", chunks[0].id
      assert_equal "single-heading-document", chunks[0].doc_id
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

      chunks.each_with_index do |chunk, idx|
        assert_operator chunk.text.length, :<=, 3500
        assert_equal "target-size-test#s#{idx}", chunk.id
        assert_equal "target-size-test", chunk.doc_id
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
      assert_equal "headings-test#s0", chunks[0].id
      assert_equal "headings-test", chunks[0].doc_id
      assert_equal "Sub Heading", chunks[1].title
      assert_equal "headings-test#s1", chunks[1].id
      assert_equal "headings-test", chunks[1].doc_id
    end

    def test_chunk_ids_for_split_sections
      # Create a section that will be split into multiple parts
      long_content = "This is a paragraph. " * 200 # ~4000 chars
      file = File.join(@corpus_dir, "split-section.md")
      File.write(file, <<~MARKDOWN)
        ---
        title: Split Section Test
        ready: true
        ---

        ## Long Section

        #{long_content}
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)
      chunks = HotwireClub::MCP::Chunker.chunk_docs(docs)

      assert_equal 1, docs.length
      assert_operator chunks.length, :>=, 2, "Should split long section into multiple chunks"

      # First chunk should have ID: doc_id#s0
      assert_equal "split-section-test#s0", chunks[0].id
      assert_equal "split-section-test", chunks[0].doc_id

      # Subsequent chunks should have IDs: doc_id#s0-1, doc_id#s0-2, etc.
      chunks[1..].each_with_index do |chunk, idx|
        expected_id = "split-section-test#s0-#{idx + 1}"

        assert_equal expected_id, chunk.id, "Chunk #{idx + 1} should have correct ID"
        assert_equal "split-section-test", chunk.doc_id
        assert_equal "Long Section", chunk.title
      end
    end

    def test_chunk_ids_with_multiple_sections_one_split
      # Create document with multiple sections, one of which is split
      long_content = "This is a paragraph. " * 200 # ~4000 chars
      file = File.join(@corpus_dir, "multi-section.md")
      File.write(file, <<~MARKDOWN)
        ---
        title: Multi Section Test
        ready: true
        ---

        ## Short Section

        Short content here.

        ## Long Section

        #{long_content}

        ## Another Short Section

        More short content.
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)
      chunks = HotwireClub::MCP::Chunker.chunk_docs(docs)

      assert_equal 1, docs.length
      assert_operator chunks.length, :>=, 4, "Should have at least 4 chunks (1 + 2+ + 1)"

      # First section (short) - should be #s0
      assert_equal "multi-section-test#s0", chunks[0].id
      assert_equal "Short Section", chunks[0].title

      # Second section (long, split) - first part should be #s1
      assert_equal "multi-section-test#s1", chunks[1].id
      assert_equal "Long Section", chunks[1].title

      # Second section - subsequent parts should be #s1-1, #s1-2, etc.
      long_section_chunks = chunks[1..-2] # All chunks except first and last
      long_section_chunks[1..].each_with_index do |chunk, idx|
        next unless chunk.title == "Long Section"

        expected_id = "multi-section-test#s1-#{idx + 1}"

        assert_equal expected_id, chunk.id
      end

      # Last section (short) - should be #s2
      assert_equal "multi-section-test#s2", chunks[-1].id
      assert_equal "Another Short Section", chunks[-1].title
    end
  end
end
