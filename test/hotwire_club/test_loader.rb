# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "fileutils"

module HotwireClub
  class TestLoader < Minitest::Test
    def setup
      @temp_dir = Dir.mktmpdir
      @corpus_dir = File.join(@temp_dir, "corpus")
      FileUtils.mkdir_p(@corpus_dir)
    end

    def teardown
      FileUtils.rm_rf(@temp_dir)
    end

    def test_filters_out_documents_without_ready_true
      # Create a file without ready: true
      file_without_ready = File.join(@corpus_dir, "not-ready.md")
      File.write(file_without_ready, <<~MARKDOWN)
        ---
        title: Not Ready Document
        ---

        This document is not ready.
      MARKDOWN

      # Create a file with ready: true
      file_with_ready = File.join(@corpus_dir, "ready.md")
      File.write(file_with_ready, <<~MARKDOWN)
        ---
        title: Ready Document
        ready: true
        ---

        This document is ready.
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)

      assert_equal 1, docs.length
      assert_equal "ready-document", docs.first.id
      assert_equal "Ready Document", docs.first.title
      assert_nil docs.first.date
    end

    def test_filters_out_documents_with_ready_false
      # Create a file with ready: false
      file_with_ready_false = File.join(@corpus_dir, "not-ready.md")
      File.write(file_with_ready_false, <<~MARKDOWN)
        ---
        title: Not Ready Document
        ready: false
        ---

        This document is not ready.
      MARKDOWN

      # Create a file with ready: true
      file_with_ready = File.join(@corpus_dir, "ready.md")
      File.write(file_with_ready, <<~MARKDOWN)
        ---
        title: Ready Document
        ready: true
        ---

        This document is ready.
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)

      assert_equal 1, docs.length
      assert_equal "ready-document", docs.first.id
      assert_nil docs.first.date
    end

    def test_uses_front_matter_metadata
      file = File.join(@corpus_dir, "test-doc.md")
      File.write(file, <<~MARKDOWN)
        ---
        title: Test Document
        date: 2023-04-25
        categories:
          - Turbo Drive
          - Stimulus
        tags:
          - rendering
          - events
        description: This is a test description
        ready: true
        ---

        This is the body content.
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)

      assert_equal 1, docs.length
      doc = docs.first

      assert_equal "test-document", doc.id
      assert_equal "Test Document", doc.title
      assert_equal Date.new(2023, 4, 25), doc.date
      assert_equal "Turbo Drive", doc.category
      assert_equal ["rendering", "events"], doc.tags
      assert_equal "This is a test description", doc.summary
      assert_equal "This is the body content.\n", doc.body
    end

    def test_tags_normalized_to_array
      # Test with array tags
      file1 = File.join(@corpus_dir, "array-tags.md")
      File.write(file1, <<~MARKDOWN)
        ---
        title: Array Tags
        tags:
          - tag1
          - tag2
        ready: true
        ---

        Content
      MARKDOWN

      # Test with string tag
      file2 = File.join(@corpus_dir, "string-tag.md")
      File.write(file2, <<~MARKDOWN)
        ---
        title: String Tag
        tags: single-tag
        ready: true
        ---

        Content
      MARKDOWN

      # Test with no tags
      file3 = File.join(@corpus_dir, "no-tags.md")
      File.write(file3, <<~MARKDOWN)
        ---
        title: No Tags
        ready: true
        ---

        Content
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)

      assert_equal 3, docs.length

      array_tags_doc = docs.find { |d| d.title == "Array Tags" }

      assert_equal ["tag1", "tag2"], array_tags_doc.tags

      string_tag_doc = docs.find { |d| d.title == "String Tag" }

      assert_equal ["single-tag"], string_tag_doc.tags

      no_tags_doc = docs.find { |d| d.title == "No Tags" }

      assert_empty no_tags_doc.tags
    end

    def test_infers_title_from_filename_when_missing
      file = File.join(@corpus_dir, "no-title.md")
      File.write(file, <<~MARKDOWN)
        ---
        ready: true
        ---

        Content
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)

      assert_equal 1, docs.length
      assert_equal "no-title", docs.first.id
      assert_equal "no-title", docs.first.title
    end

    def test_infers_category_from_first_category
      file = File.join(@corpus_dir, "test.md")
      File.write(file, <<~MARKDOWN)
        ---
        title: Test
        categories:
          - First Category
          - Second Category
        ready: true
        ---

        Content
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)

      assert_equal 1, docs.length
      assert_equal "First Category", docs.first.category
    end

    def test_uses_category_when_categories_not_present
      file = File.join(@corpus_dir, "test.md")
      File.write(file, <<~MARKDOWN)
        ---
        title: Test
        category: Single Category
        ready: true
        ---

        Content
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)

      assert_equal 1, docs.length
      assert_equal "Single Category", docs.first.category
    end

    def test_summary_falls_back_to_first_paragraph_when_description_missing
      file = File.join(@corpus_dir, "test.md")
      File.write(file, <<~MARKDOWN)
        ---
        title: Test
        ready: true
        ---

        This is the first paragraph.

        This is the second paragraph.
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)

      assert_equal 1, docs.length
      assert_equal "This is the first paragraph.", docs.first.summary
    end

    def test_parses_date_from_front_matter
      file = File.join(@corpus_dir, "test.md")
      File.write(file, <<~MARKDOWN)
        ---
        title: Test Document
        date: 2023-04-25
        ready: true
        ---

        Content
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)

      assert_equal 1, docs.length
      assert_equal Date.new(2023, 4, 25), docs.first.date
    end

    def test_date_is_nil_when_not_present
      file = File.join(@corpus_dir, "test.md")
      File.write(file, <<~MARKDOWN)
        ---
        title: Test Document
        ready: true
        ---

        Content
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)

      assert_equal 1, docs.length
      assert_nil docs.first.date
    end

    def test_returns_empty_array_when_corpus_directory_does_not_exist
      docs = HotwireClub::MCP::Loader.load_docs("/nonexistent/directory")

      assert_empty docs
    end

    def test_returns_empty_array_when_no_markdown_files
      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)

      assert_empty docs
    end

    def test_filters_out_documents_without_free_true_when_free_only_true
      # Create a file with ready: true but free: false
      file_not_free = File.join(@corpus_dir, "not-free.md")
      File.write(file_not_free, <<~MARKDOWN)
        ---
        title: Not Free Document
        ready: true
        free: false
        ---

        This document is not free.
      MARKDOWN

      # Create a file with ready: true and free: true
      file_free = File.join(@corpus_dir, "free.md")
      File.write(file_free, <<~MARKDOWN)
        ---
        title: Free Document
        ready: true
        free: true
        ---

        This document is free.
      MARKDOWN

      # Create a file with ready: true but no free flag (should be excluded when free_only: true)
      file_no_free_flag = File.join(@corpus_dir, "no-free-flag.md")
      File.write(file_no_free_flag, <<~MARKDOWN)
        ---
        title: No Free Flag Document
        ready: true
        ---

        This document has no free flag.
      MARKDOWN

      docs = HotwireClub::MCP::FreeLoader.load_docs(@corpus_dir)

      assert_equal 1, docs.length
      assert_equal "free-document", docs.first.id
      assert_equal "Free Document", docs.first.title
    end

    def test_includes_all_ready_documents_when_using_pro_loader
      # Create a file with ready: true but free: false
      file_not_free = File.join(@corpus_dir, "not-free.md")
      File.write(file_not_free, <<~MARKDOWN)
        ---
        title: Not Free Document
        ready: true
        free: false
        ---

        This document is not free.
      MARKDOWN

      # Create a file with ready: true and free: true
      file_free = File.join(@corpus_dir, "free.md")
      File.write(file_free, <<~MARKDOWN)
        ---
        title: Free Document
        ready: true
        free: true
        ---

        This document is free.
      MARKDOWN

      # Create a file with ready: true but no free flag
      file_no_free_flag = File.join(@corpus_dir, "no-free-flag.md")
      File.write(file_no_free_flag, <<~MARKDOWN)
        ---
        title: No Free Flag Document
        ready: true
        ---

        This document has no free flag.
      MARKDOWN

      docs = HotwireClub::MCP::ProLoader.load_docs(@corpus_dir)

      assert_equal 3, docs.length
      doc_ids = docs.map(&:id).sort

      assert_equal ["free-document", "no-free-flag-document", "not-free-document"], doc_ids
    end

    def test_includes_all_ready_documents_when_using_base_loader
      # Create a file with ready: true but free: false
      file_not_free = File.join(@corpus_dir, "not-free.md")
      File.write(file_not_free, <<~MARKDOWN)
        ---
        title: Not Free Document
        ready: true
        free: false
        ---

        This document is not free.
      MARKDOWN

      # Create a file with ready: true and free: true
      file_free = File.join(@corpus_dir, "free.md")
      File.write(file_free, <<~MARKDOWN)
        ---
        title: Free Document
        ready: true
        free: true
        ---

        This document is free.
      MARKDOWN

      # Create a file with ready: true but no free flag
      file_no_free_flag = File.join(@corpus_dir, "no-free-flag.md")
      File.write(file_no_free_flag, <<~MARKDOWN)
        ---
        title: No Free Flag Document
        ready: true
        ---

        This document has no free flag.
      MARKDOWN

      docs = HotwireClub::MCP::Loader.load_docs(@corpus_dir)

      assert_equal 3, docs.length
      doc_ids = docs.map(&:id).sort

      assert_equal ["free-document", "no-free-flag-document", "not-free-document"], doc_ids
    end

    def test_respects_ready_flag_even_when_free_only_true
      # Create a file with free: true but ready: false (should be excluded)
      file_not_ready = File.join(@corpus_dir, "not-ready.md")
      File.write(file_not_ready, <<~MARKDOWN)
        ---
        title: Not Ready Document
        ready: false
        free: true
        ---

        This document is not ready.
      MARKDOWN

      # Create a file with ready: true and free: true
      file_ready_and_free = File.join(@corpus_dir, "ready-free.md")
      File.write(file_ready_and_free, <<~MARKDOWN)
        ---
        title: Ready and Free Document
        ready: true
        free: true
        ---

        This document is ready and free.
      MARKDOWN

      docs = HotwireClub::MCP::FreeLoader.load_docs(@corpus_dir)

      assert_equal 1, docs.length
      assert_equal "ready-and-free-document", docs.first.id
    end

    def test_generates_id_from_title
      assert_equal "test-document", HotwireClub::MCP::Doc.id_from_title("Test Document")
      assert_equal "turbo-drive-custom-rendering", HotwireClub::MCP::Doc.id_from_title("Turbo Drive: Custom Rendering")
      assert_equal "simple-title", HotwireClub::MCP::Doc.id_from_title("Simple Title")
      assert_equal "with-special-chars", HotwireClub::MCP::Doc.id_from_title("With Special!@# Chars")
      assert_equal "multiple-spaces", HotwireClub::MCP::Doc.id_from_title("Multiple    Spaces")
      assert_equal "with-underscores", HotwireClub::MCP::Doc.id_from_title("With_Underscores")
      assert_equal "trailing-hyphens", HotwireClub::MCP::Doc.id_from_title("---Trailing---Hyphens---")
      assert_equal "mixed-case", HotwireClub::MCP::Doc.id_from_title("MiXeD cAsE")
      assert_nil HotwireClub::MCP::Doc.id_from_title(nil)
      assert_nil HotwireClub::MCP::Doc.id_from_title("")
    end
  end
end
