# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "sqlite3"

module HotwireClub
  class TestSchema < Minitest::Test
    def setup
      @db_path = File.join(Dir.pwd, "db", "kb.sqlite")
      @db_dir = File.dirname(@db_path)
      FileUtils.mkdir_p(@db_dir)
    end

    def teardown
      FileUtils.rm_f(@db_path)
      FileUtils.rmdir(@db_dir) if Dir.exist?(@db_dir) && Dir.empty?(@db_dir)
    end

    def test_create_deletes_existing_database
      # Create an existing database file
      FileUtils.mkdir_p(@db_dir)
      File.write(@db_path, "existing database content")

      assert_path_exists @db_path

      HotwireClub::MCP::Schema.create!

      # Verify the database was recreated (not just deleted)
      assert_path_exists @db_path
      db = SQLite3::Database.new(@db_path)
      # Should be able to query sqlite_master, which means it's a valid SQLite database
      result = db.execute("SELECT name FROM sqlite_master WHERE type='table'")

      refute_nil result
      db.close
    end

    def test_create_creates_docs_table
      HotwireClub::MCP::Schema.create!

      db = SQLite3::Database.new(@db_path)
      tables = db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='docs'")
      db.close

      assert_equal 1, tables.length
      assert_equal "docs", tables.first.first
    end

    def test_create_creates_tags_table
      HotwireClub::MCP::Schema.create!

      db = SQLite3::Database.new(@db_path)
      tables = db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='tags'")
      db.close

      assert_equal 1, tables.length
      assert_equal "tags", tables.first.first
    end

    def test_create_creates_doc_tags_table
      HotwireClub::MCP::Schema.create!

      db = SQLite3::Database.new(@db_path)
      tables = db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='doc_tags'")
      db.close

      assert_equal 1, tables.length
      assert_equal "doc_tags", tables.first.first
    end

    def test_docs_table_has_correct_schema
      HotwireClub::MCP::Schema.create!

      db = SQLite3::Database.new(@db_path)
      schema = db.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='docs'").first.first
      db.close

      assert_match(%r{CREATE TABLE docs}, schema)
      assert_match(%r{id.*PRIMARY KEY}i, schema)
      assert_match(%r{title}i, schema)
      assert_match(%r{category}i, schema)
      assert_match(%r{summary}i, schema)
      assert_match(%r{body}i, schema)
      assert_match(%r{date}i, schema)
    end

    def test_tags_table_has_correct_schema
      HotwireClub::MCP::Schema.create!

      db = SQLite3::Database.new(@db_path)
      schema = db.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='tags'").first.first
      db.close

      assert_match(%r{CREATE TABLE tags}, schema)
      assert_match(%r{name.*PRIMARY KEY}i, schema)
    end

    def test_doc_tags_table_has_correct_schema
      HotwireClub::MCP::Schema.create!

      db = SQLite3::Database.new(@db_path)
      schema = db.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='doc_tags'").first.first
      db.close

      assert_match(%r{CREATE TABLE doc_tags}, schema)
      assert_match(%r{doc_id}i, schema)
      assert_match(%r{tag}i, schema)
      assert_match(%r{PRIMARY KEY.*doc_id.*tag}i, schema)
    end

    def test_chunks_is_fts5_virtual_table
      HotwireClub::MCP::Schema.create!

      db = SQLite3::Database.new(@db_path)
      # Check for virtual table
      virtual_tables = db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='chunks'")
      db.close

      assert_equal 1, virtual_tables.length
      assert_equal "chunks", virtual_tables.first.first
    end

    def test_chunks_table_has_fts5_structure
      HotwireClub::MCP::Schema.create!

      db = SQLite3::Database.new(@db_path)
      schema = db.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='chunks'").first.first
      db.close

      assert_match(%r{CREATE VIRTUAL TABLE.*chunks.*USING fts5}i, schema)
      assert_match(%r{chunk_id}i, schema)
      assert_match(%r{doc_id}i, schema)
      assert_match(%r{title}i, schema)
      assert_match(%r{text}i, schema)
      assert_match(%r{category}i, schema)
      assert_match(%r{tags}i, schema)
      assert_match(%r{position}i, schema)
      assert_match(%r{tokenize.*porter}i, schema)
    end

    def test_all_tables_are_created
      HotwireClub::MCP::Schema.create!

      db = SQLite3::Database.new(@db_path)
      tables = db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
      db.close

      table_names = tables.map(&:first)

      assert_includes table_names, "docs"
      assert_includes table_names, "tags"
      assert_includes table_names, "doc_tags"
      assert_includes table_names, "chunks"
    end
  end
end
