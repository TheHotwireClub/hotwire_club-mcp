# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "rom"
require "securerandom"

module HotwireClub
  # Test suite for MCP Tools
  #
  # This test suite covers all MCP tools required by issue #24:
  # - search_hwc_kb - Search knowledge base chunks
  # - get_hwc_kb_chunk - Get a single chunk by ID
  # - list_hwc_kb_categories - List all categories
  # - list_hwc_kb_tags - List all tags
  # - list_hwc_kb_docs - List documents with optional filters
  # - related_hwc_kb_docs - Find related documents
  #
  # Test coverage includes:
  # - Tool registration with FastMCP server
  # - Tool argument validation
  # - Tool call method execution
  # - Error handling (invalid arguments, missing data)
  # - Return value formats and structures
  # - Integration with Database::Adapter
  class TestMcpTools < Minitest::Test
    def setup
      # Use unique database path with UUID to ensure complete isolation
      @db_path = File.join(Dir.pwd, "db", "kb-mcp-tools-test-#{SecureRandom.uuid}.sqlite")
      @db_dir = File.dirname(@db_path)
      FileUtils.mkdir_p(@db_dir)
      FileUtils.rm_f(@db_path)
      HotwireClub::MCP::Schema.create!(@db_path)
      @container = HotwireClub::MCP::Database.container(@db_path)
      setup_test_data
      @adapter = HotwireClub::MCP::Database::Adapter.new(@container)
      @server = HotwireClub::MCP::Server.new(container: @container)
    end

    def teardown
      # Clear container reference to allow garbage collection
      @container = nil
      @adapter = nil
      @server = nil
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

      # Create chunks
      @container.relations[:chunks].insert(
        chunk_id: "doc-1#s0",
        doc_id:   "doc-1",
        title:    "Introduction to Ruby",
        text:     "Ruby is a dynamic, reflective, object-oriented, general-purpose programming language.",
        category: "programming",
        tags:     "ruby,backend",
        position: 0,
      )
      @container.relations[:chunks].insert(
        chunk_id: "doc-2#s0",
        doc_id:   "doc-2",
        title:    "Python Introduction",
        text:     "Python is a high-level, interpreted programming language with dynamic semantics.",
        category: "programming",
        tags:     "python,backend",
        position: 0,
      )
      @container.relations[:chunks].insert(
        chunk_id: "doc-3#s0",
        doc_id:   "doc-3",
        title:    "JavaScript Basics",
        text:     "JavaScript is a scripting language that enables you to create dynamically updating content.",
        category: "frontend",
        tags:     "javascript,frontend",
        position: 0,
      )
    end

    # ============================================================================
    # Tests for search_hwc_kb tool
    # ============================================================================

    def test_search_hwc_kb_tool_exists
      assert defined?(HotwireClub::MCP::Tools::SearchHwcKbTool)
      assert_operator HotwireClub::MCP::Tools::SearchHwcKbTool, :<, HotwireClub::MCP::Tools::BaseTool
    end

    def test_search_hwc_kb_tool_is_registered
      tool_classes = @server.tools.values

      assert_includes tool_classes, HotwireClub::MCP::Tools::SearchHwcKbTool
    end

    def test_search_hwc_kb_has_correct_description
      tool_class = @server.tools.values.find { |tc| tc == HotwireClub::MCP::Tools::SearchHwcKbTool }

      refute_nil tool_class
      assert_includes tool_class.description.downcase, "search"
    end

    def test_search_hwc_kb_requires_query_argument
      tool = HotwireClub::MCP::Tools::SearchHwcKbTool.new
      HotwireClub::MCP::Tools::SearchHwcKbTool.adapter = @adapter

      assert_raises(ArgumentError) { tool.call({}) }
    end

    def test_search_hwc_kb_accepts_optional_category_argument
      tool = HotwireClub::MCP::Tools::SearchHwcKbTool.new
      HotwireClub::MCP::Tools::SearchHwcKbTool.adapter = @adapter
      result = tool.call(query: "Ruby", category: "programming")

      assert_kind_of Array, result
    end

    def test_search_hwc_kb_accepts_optional_tags_argument
      tool = HotwireClub::MCP::Tools::SearchHwcKbTool.new
      HotwireClub::MCP::Tools::SearchHwcKbTool.adapter = @adapter
      result = tool.call(query: "Ruby", tags: ["ruby"])

      assert_kind_of Array, result
    end

    def test_search_hwc_kb_accepts_optional_limit_argument
      tool = HotwireClub::MCP::Tools::SearchHwcKbTool.new
      HotwireClub::MCP::Tools::SearchHwcKbTool.adapter = @adapter
      result = tool.call(query: "Ruby", limit: 5)

      assert_operator result.length, :<=, 5
    end

    def test_search_hwc_kb_returns_search_results
      tool = HotwireClub::MCP::Tools::SearchHwcKbTool.new
      HotwireClub::MCP::Tools::SearchHwcKbTool.adapter = @adapter
      result = tool.call(query: "Ruby")

      assert_kind_of Array, result
      assert_predicate result, :any?
      assert result.first.key?("chunk_id")
    end

    def test_search_hwc_kb_filters_by_category
      tool = HotwireClub::MCP::Tools::SearchHwcKbTool.new
      HotwireClub::MCP::Tools::SearchHwcKbTool.adapter = @adapter
      result = tool.call(query: "programming", category: "programming")

      assert result.all? { |r| r["category"] == "programming" }
    end

    def test_search_hwc_kb_filters_by_tags
      tool = HotwireClub::MCP::Tools::SearchHwcKbTool.new
      HotwireClub::MCP::Tools::SearchHwcKbTool.adapter = @adapter
      result = tool.call(query: "language", tags: ["ruby"])

      assert result.all? { |r| r["tags"].include?("ruby") }
    end

    def test_search_hwc_kb_handles_empty_query
      tool = HotwireClub::MCP::Tools::SearchHwcKbTool.new
      HotwireClub::MCP::Tools::SearchHwcKbTool.adapter = @adapter
      result = tool.call(query: "")

      assert_kind_of Array, result
    end

    def test_search_hwc_kb_handles_nonexistent_category
      tool = HotwireClub::MCP::Tools::SearchHwcKbTool.new
      HotwireClub::MCP::Tools::SearchHwcKbTool.adapter = @adapter
      result = tool.call(query: "test", category: "nonexistent")

      assert_empty result
    end

    # ============================================================================
    # Tests for get_hwc_kb_chunk tool
    # ============================================================================

    def test_get_hwc_kb_chunk_tool_exists
      assert defined?(HotwireClub::MCP::Tools::GetHwcKbChunkTool)
      assert_operator HotwireClub::MCP::Tools::GetHwcKbChunkTool, :<, HotwireClub::MCP::Tools::BaseTool
    end

    def test_get_hwc_kb_chunk_tool_is_registered
      tool_classes = @server.tools.values

      assert_includes tool_classes, HotwireClub::MCP::Tools::GetHwcKbChunkTool
    end

    def test_get_hwc_kb_chunk_has_correct_description
      tool_class = @server.tools.values.find { |tc| tc == HotwireClub::MCP::Tools::GetHwcKbChunkTool }

      refute_nil tool_class
      assert_includes tool_class.description.downcase, "chunk"
    end

    def test_get_hwc_kb_chunk_requires_chunk_id_argument
      tool = HotwireClub::MCP::Tools::GetHwcKbChunkTool.new
      HotwireClub::MCP::Tools::GetHwcKbChunkTool.adapter = @adapter

      assert_raises(ArgumentError) { tool.call({}) }
    end

    def test_get_hwc_kb_chunk_returns_chunk_by_id
      tool = HotwireClub::MCP::Tools::GetHwcKbChunkTool.new
      HotwireClub::MCP::Tools::GetHwcKbChunkTool.adapter = @adapter
      result = tool.call(chunk_id: "doc-1#s0")

      assert_kind_of Hash, result
      assert_equal "doc-1#s0", result["chunk_id"]
    end

    def test_get_hwc_kb_chunk_returns_nil_for_nonexistent_id
      tool = HotwireClub::MCP::Tools::GetHwcKbChunkTool.new
      HotwireClub::MCP::Tools::GetHwcKbChunkTool.adapter = @adapter
      result = tool.call(chunk_id: "nonexistent-chunk-id")

      assert_nil result
    end

    def test_get_hwc_kb_chunk_handles_empty_chunk_id
      tool = HotwireClub::MCP::Tools::GetHwcKbChunkTool.new
      HotwireClub::MCP::Tools::GetHwcKbChunkTool.adapter = @adapter
      result = tool.call(chunk_id: "")

      assert_nil result
    end

    def test_get_hwc_kb_chunk_returns_all_chunk_fields
      tool = HotwireClub::MCP::Tools::GetHwcKbChunkTool.new
      HotwireClub::MCP::Tools::GetHwcKbChunkTool.adapter = @adapter
      result = tool.call(chunk_id: "doc-1#s0")

      assert_includes result.keys, "chunk_id"
      assert_includes result.keys, "doc_id"
      assert_includes result.keys, "title"
      assert_includes result.keys, "text"
      assert_includes result.keys, "category"
      assert_includes result.keys, "tags"
      assert_includes result.keys, "position"
    end

    # ============================================================================
    # Tests for list_hwc_kb_categories tool
    # ============================================================================

    def test_list_hwc_kb_categories_tool_exists
      assert defined?(HotwireClub::MCP::Tools::ListHwcKbCategoriesTool)
      assert_operator HotwireClub::MCP::Tools::ListHwcKbCategoriesTool, :<, HotwireClub::MCP::Tools::BaseTool
    end

    def test_list_hwc_kb_categories_tool_is_registered
      tool_classes = @server.tools.values

      assert_includes tool_classes, HotwireClub::MCP::Tools::ListHwcKbCategoriesTool
    end

    def test_list_hwc_kb_categories_has_correct_description
      tool_class = @server.tools.values.find { |tc| tc == HotwireClub::MCP::Tools::ListHwcKbCategoriesTool }

      refute_nil tool_class
      assert_includes tool_class.description.downcase, "categor"
    end

    def test_list_hwc_kb_categories_has_no_required_arguments
      tool = HotwireClub::MCP::Tools::ListHwcKbCategoriesTool.new
      HotwireClub::MCP::Tools::ListHwcKbCategoriesTool.adapter = @adapter
      result = tool.call

      assert_kind_of Array, result
    end

    def test_list_hwc_kb_categories_returns_array_of_strings
      tool = HotwireClub::MCP::Tools::ListHwcKbCategoriesTool.new
      HotwireClub::MCP::Tools::ListHwcKbCategoriesTool.adapter = @adapter
      result = tool.call

      assert_kind_of Array, result
      assert result.all? { |cat| cat.is_a?(String) }
    end

    def test_list_hwc_kb_categories_returns_unique_categories
      tool = HotwireClub::MCP::Tools::ListHwcKbCategoriesTool.new
      HotwireClub::MCP::Tools::ListHwcKbCategoriesTool.adapter = @adapter
      result = tool.call

      assert_equal result.length, result.uniq.length
    end

    def test_list_hwc_kb_categories_includes_all_categories
      tool = HotwireClub::MCP::Tools::ListHwcKbCategoriesTool.new
      HotwireClub::MCP::Tools::ListHwcKbCategoriesTool.adapter = @adapter
      result = tool.call

      assert_includes result, "programming"
      assert_includes result, "frontend"
    end

    def test_list_hwc_kb_categories_returns_empty_array_when_no_categories
      # Create empty database
      empty_db_path = File.join(Dir.pwd, "db", "kb-empty-test-#{SecureRandom.uuid}.sqlite")
      FileUtils.mkdir_p(File.dirname(empty_db_path))
      HotwireClub::MCP::Schema.create!(empty_db_path)
      empty_container = HotwireClub::MCP::Database.container(empty_db_path)
      empty_adapter = HotwireClub::MCP::Database::Adapter.new(empty_container)

      tool = HotwireClub::MCP::Tools::ListHwcKbCategoriesTool.new
      HotwireClub::MCP::Tools::ListHwcKbCategoriesTool.adapter = empty_adapter
      result = tool.call

      assert_empty result

      FileUtils.rm_f(empty_db_path)
    end

    # ============================================================================
    # Tests for list_hwc_kb_tags tool
    # ============================================================================

    def test_list_hwc_kb_tags_tool_exists
      assert defined?(HotwireClub::MCP::Tools::ListHwcKbTagsTool)
      assert_operator HotwireClub::MCP::Tools::ListHwcKbTagsTool, :<, HotwireClub::MCP::Tools::BaseTool
    end

    def test_list_hwc_kb_tags_tool_is_registered
      tool_classes = @server.tools.values

      assert_includes tool_classes, HotwireClub::MCP::Tools::ListHwcKbTagsTool
    end

    def test_list_hwc_kb_tags_has_correct_description
      tool_class = @server.tools.values.find { |tc| tc == HotwireClub::MCP::Tools::ListHwcKbTagsTool }

      refute_nil tool_class
      assert_includes tool_class.description.downcase, "tag"
    end

    def test_list_hwc_kb_tags_has_no_required_arguments
      tool = HotwireClub::MCP::Tools::ListHwcKbTagsTool.new
      HotwireClub::MCP::Tools::ListHwcKbTagsTool.adapter = @adapter
      result = tool.call

      assert_kind_of Array, result
    end

    def test_list_hwc_kb_tags_returns_array_of_strings
      tool = HotwireClub::MCP::Tools::ListHwcKbTagsTool.new
      HotwireClub::MCP::Tools::ListHwcKbTagsTool.adapter = @adapter
      result = tool.call

      assert_kind_of Array, result
      assert result.all? { |tag| tag.is_a?(String) }
    end

    def test_list_hwc_kb_tags_returns_unique_tags
      tool = HotwireClub::MCP::Tools::ListHwcKbTagsTool.new
      HotwireClub::MCP::Tools::ListHwcKbTagsTool.adapter = @adapter
      result = tool.call

      assert_equal result.length, result.uniq.length
    end

    def test_list_hwc_kb_tags_includes_all_tags
      tool = HotwireClub::MCP::Tools::ListHwcKbTagsTool.new
      HotwireClub::MCP::Tools::ListHwcKbTagsTool.adapter = @adapter
      result = tool.call

      assert_includes result, "ruby"
      assert_includes result, "python"
      assert_includes result, "javascript"
    end

    def test_list_hwc_kb_tags_returns_empty_array_when_no_tags
      # Create empty database
      empty_db_path = File.join(Dir.pwd, "db", "kb-empty-test-#{SecureRandom.uuid}.sqlite")
      FileUtils.mkdir_p(File.dirname(empty_db_path))
      HotwireClub::MCP::Schema.create!(empty_db_path)
      empty_container = HotwireClub::MCP::Database.container(empty_db_path)
      empty_adapter = HotwireClub::MCP::Database::Adapter.new(empty_container)

      tool = HotwireClub::MCP::Tools::ListHwcKbTagsTool.new
      HotwireClub::MCP::Tools::ListHwcKbTagsTool.adapter = empty_adapter
      result = tool.call

      assert_empty result

      FileUtils.rm_f(empty_db_path)
    end

    # ============================================================================
    # Tests for list_hwc_kb_docs tool
    # ============================================================================

    def test_list_hwc_kb_docs_tool_exists
      assert defined?(HotwireClub::MCP::Tools::ListHwcKbDocsTool)
      assert_operator HotwireClub::MCP::Tools::ListHwcKbDocsTool, :<, HotwireClub::MCP::Tools::BaseTool
    end

    def test_list_hwc_kb_docs_tool_is_registered
      tool_classes = @server.tools.values

      assert_includes tool_classes, HotwireClub::MCP::Tools::ListHwcKbDocsTool
    end

    def test_list_hwc_kb_docs_has_correct_description
      tool_class = @server.tools.values.find { |tc| tc == HotwireClub::MCP::Tools::ListHwcKbDocsTool }

      refute_nil tool_class
      assert_includes tool_class.description.downcase, "doc"
    end

    def test_list_hwc_kb_docs_has_no_required_arguments
      tool = HotwireClub::MCP::Tools::ListHwcKbDocsTool.new
      HotwireClub::MCP::Tools::ListHwcKbDocsTool.adapter = @adapter
      result = tool.call

      assert_kind_of Array, result
    end

    def test_list_hwc_kb_docs_accepts_optional_category_argument
      tool = HotwireClub::MCP::Tools::ListHwcKbDocsTool.new
      HotwireClub::MCP::Tools::ListHwcKbDocsTool.adapter = @adapter
      result = tool.call(category: "programming")

      assert_kind_of Array, result
      assert result.all? { |doc| (doc[:category] || doc.category) == "programming" }
    end

    def test_list_hwc_kb_docs_accepts_optional_tags_argument
      tool = HotwireClub::MCP::Tools::ListHwcKbDocsTool.new
      HotwireClub::MCP::Tools::ListHwcKbDocsTool.adapter = @adapter
      result = tool.call(tags: ["ruby"])

      assert_kind_of Array, result
    end

    def test_list_hwc_kb_docs_accepts_optional_limit_argument
      tool = HotwireClub::MCP::Tools::ListHwcKbDocsTool.new
      HotwireClub::MCP::Tools::ListHwcKbDocsTool.adapter = @adapter
      result = tool.call(limit: 2)

      assert_operator result.length, :<=, 2
    end

    def test_list_hwc_kb_docs_accepts_optional_offset_argument
      tool = HotwireClub::MCP::Tools::ListHwcKbDocsTool.new
      HotwireClub::MCP::Tools::ListHwcKbDocsTool.adapter = @adapter
      result = tool.call(offset: 1)

      assert_kind_of Array, result
    end

    def test_list_hwc_kb_docs_returns_all_docs_by_default
      tool = HotwireClub::MCP::Tools::ListHwcKbDocsTool.new
      HotwireClub::MCP::Tools::ListHwcKbDocsTool.adapter = @adapter
      result = tool.call

      assert_operator result.length, :>=, 3
    end

    def test_list_hwc_kb_docs_filters_by_category
      tool = HotwireClub::MCP::Tools::ListHwcKbDocsTool.new
      HotwireClub::MCP::Tools::ListHwcKbDocsTool.adapter = @adapter
      result = tool.call(category: "programming")

      assert result.all? { |doc| (doc[:category] || doc.category) == "programming" }
    end

    def test_list_hwc_kb_docs_filters_by_tags
      tool = HotwireClub::MCP::Tools::ListHwcKbDocsTool.new
      HotwireClub::MCP::Tools::ListHwcKbDocsTool.adapter = @adapter
      result = tool.call(tags: ["ruby"])
      doc_ids = result.map { |doc| doc[:id] || doc.id }

      assert_includes doc_ids, "doc-1"
    end

    def test_list_hwc_kb_docs_respects_limit
      tool = HotwireClub::MCP::Tools::ListHwcKbDocsTool.new
      HotwireClub::MCP::Tools::ListHwcKbDocsTool.adapter = @adapter
      result = tool.call(limit: 2)

      assert_operator result.length, :<=, 2
    end

    def test_list_hwc_kb_docs_respects_offset
      tool = HotwireClub::MCP::Tools::ListHwcKbDocsTool.new
      HotwireClub::MCP::Tools::ListHwcKbDocsTool.adapter = @adapter
      all_docs = tool.call(limit: 100)
      offset_docs = tool.call(limit: 100, offset: 1)

      assert_equal all_docs.length - 1, offset_docs.length
    end

    # ============================================================================
    # Tests for related_hwc_kb_docs tool
    # ============================================================================

    def test_related_hwc_kb_docs_tool_exists
      assert defined?(HotwireClub::MCP::Tools::RelatedHwcKbDocsTool)
      assert_operator HotwireClub::MCP::Tools::RelatedHwcKbDocsTool, :<, HotwireClub::MCP::Tools::BaseTool
    end

    def test_related_hwc_kb_docs_tool_is_registered
      tool_classes = @server.tools.values

      assert_includes tool_classes, HotwireClub::MCP::Tools::RelatedHwcKbDocsTool
    end

    def test_related_hwc_kb_docs_has_correct_description
      tool_class = @server.tools.values.find { |tc| tc == HotwireClub::MCP::Tools::RelatedHwcKbDocsTool }

      refute_nil tool_class
      assert_includes tool_class.description.downcase, "related"
    end

    def test_related_hwc_kb_docs_accepts_doc_id_argument
      tool = HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.new
      HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.adapter = @adapter
      result = tool.call(doc_id: "doc-1", limit: 5)

      assert_kind_of Array, result
    end

    def test_related_hwc_kb_docs_accepts_chunk_id_argument
      tool = HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.new
      HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.adapter = @adapter
      result = tool.call(chunk_id: "doc-1#s0", limit: 5)

      assert_kind_of Array, result
    end

    def test_related_hwc_kb_docs_accepts_optional_limit_argument
      tool = HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.new
      HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.adapter = @adapter
      result = tool.call(doc_id: "doc-1", limit: 2)

      assert_operator result.length, :<=, 2
    end

    def test_related_hwc_kb_docs_requires_at_least_one_identifier
      tool = HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.new
      HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.adapter = @adapter

      assert_raises(ArgumentError) { tool.call({}) }
    end

    def test_related_hwc_kb_docs_returns_related_docs_by_doc_id
      tool = HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.new
      HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.adapter = @adapter
      result = tool.call(doc_id: "doc-1", limit: 10)

      assert_predicate result, :any?
      doc_ids = result.map { |doc| doc[:id] || doc.id }

      assert_includes doc_ids, "doc-2" # Should find doc-2 (same category, tag overlap)
    end

    def test_related_hwc_kb_docs_returns_related_docs_by_chunk_id
      tool = HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.new
      HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.adapter = @adapter
      result = tool.call(chunk_id: "doc-1#s0", limit: 10)

      assert_predicate result, :any?
      doc_ids = result.map { |doc| doc[:id] || doc.id }

      assert_includes doc_ids, "doc-2"
    end

    def test_related_hwc_kb_docs_excludes_source_doc
      tool = HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.new
      HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.adapter = @adapter
      result = tool.call(doc_id: "doc-1", limit: 10)
      doc_ids = result.map { |doc| doc[:id] || doc.id }

      refute_includes doc_ids, "doc-1"
    end

    def test_related_hwc_kb_docs_respects_limit
      tool = HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.new
      HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.adapter = @adapter
      result = tool.call(doc_id: "doc-1", limit: 1)

      assert_operator result.length, :<=, 1
    end

    def test_related_hwc_kb_docs_returns_empty_array_when_no_related_docs
      tool = HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.new
      HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.adapter = @adapter
      result = tool.call(doc_id: "doc-3", limit: 10) # doc-3 has unique tags

      assert_empty result
    end

    def test_related_hwc_kb_docs_handles_nonexistent_doc_id
      tool = HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.new
      HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.adapter = @adapter
      result = tool.call(doc_id: "nonexistent-doc", limit: 10)

      assert_empty result
    end

    def test_related_hwc_kb_docs_handles_nonexistent_chunk_id
      tool = HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.new
      HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.adapter = @adapter
      result = tool.call(chunk_id: "nonexistent-chunk", limit: 10)

      assert_empty result
    end

    def test_related_hwc_kb_docs_prioritizes_doc_id_over_chunk_id
      tool = HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.new
      HotwireClub::MCP::Tools::RelatedHwcKbDocsTool.adapter = @adapter
      result = tool.call(doc_id: "doc-2", chunk_id: "doc-1#s0", limit: 10)
      # Should find docs related to doc-2, not doc-1
      doc_ids = result.map { |doc| doc[:id] || doc.id }

      assert_includes doc_ids, "doc-1" # doc-1 is related to doc-2
    end

    # ============================================================================
    # Integration tests
    # ============================================================================

    def test_all_tools_are_registered_with_server
      expected_tool_classes = [
        HotwireClub::MCP::Tools::SearchHwcKbTool,
        HotwireClub::MCP::Tools::GetHwcKbChunkTool,
        HotwireClub::MCP::Tools::ListHwcKbCategoriesTool,
        HotwireClub::MCP::Tools::ListHwcKbTagsTool,
        HotwireClub::MCP::Tools::ListHwcKbDocsTool,
        HotwireClub::MCP::Tools::RelatedHwcKbDocsTool,
      ]
      registered_tool_classes = @server.tools.values

      expected_tool_classes.each do |tool_class|
        assert_includes registered_tool_classes, tool_class, "Tool #{tool_class} should be registered"
      end
      assert_equal 6, @server.tools.length
    end

    def test_tools_use_adapter_correctly
      # Test that tools properly delegate to adapter
      search_tool = HotwireClub::MCP::Tools::SearchHwcKbTool.new
      HotwireClub::MCP::Tools::SearchHwcKbTool.adapter = @adapter
      search_result = search_tool.call(query: "Ruby")

      # Verify adapter was used (results should match adapter.search)
      adapter_result = @adapter.search(query: "Ruby")

      assert_equal adapter_result.length, search_result.length
    end

    def test_tools_return_consistent_data_formats
      # Test that tools return JSON-serializable structures
      tools_to_test = [
        [HotwireClub::MCP::Tools::SearchHwcKbTool, {query: "Ruby"}],
        [HotwireClub::MCP::Tools::GetHwcKbChunkTool, {chunk_id: "doc-1#s0"}],
        [HotwireClub::MCP::Tools::ListHwcKbCategoriesTool, nil],
        [HotwireClub::MCP::Tools::ListHwcKbTagsTool, nil],
        [HotwireClub::MCP::Tools::ListHwcKbDocsTool, nil],
        [HotwireClub::MCP::Tools::RelatedHwcKbDocsTool, {doc_id: "doc-1", limit: 5}],
      ]

      tools_to_test.each do |tool_class, args|
        tool_class.adapter = @adapter
        tool = tool_class.new
        result = args ? tool.call(**args) : tool.call

        # Verify result is JSON-serializable (basic check)
        assert result.is_a?(Array) || result.is_a?(Hash) || result.nil?, "Result should be Array, Hash, or nil, got #{result.class}"
        if result.is_a?(Array) && result.any?
          first_item = result.first
          # ROM structs respond to to_h and can be serialized
          assert first_item.is_a?(Hash) || first_item.is_a?(String) || first_item.respond_to?(:to_h), "Array elements should be Hash, String, or respond to to_h, got #{first_item.class}"
        end
      end
    end
  end
end
