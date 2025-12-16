# frozen_string_literal: true

require "sqlite3"
require "fileutils"

module HotwireClub
  module MCP
    class Schema
      DB_PATH = File.join(Dir.pwd, "db", "kb.sqlite")

      def self.create!(db_path = DB_PATH)
        db_dir = File.dirname(db_path)
        FileUtils.mkdir_p(db_dir)
        FileUtils.rm_f(db_path)

        db = SQLite3::Database.new(db_path)

        create_docs_table(db)
        create_tags_table(db)
        create_doc_tags_table(db)
        create_chunks_table(db)

        db.close
      end

      # Create docs table
      #
      # @param db [SQLite3::Database] Database connection
      def self.create_docs_table(db)
        db.execute <<~SQL
          CREATE TABLE docs (
            id TEXT PRIMARY KEY,
            title TEXT,
            category TEXT,
            summary TEXT,
            body TEXT,
            date TEXT
          )
        SQL
      end

      # Create tags table
      #
      # @param db [SQLite3::Database] Database connection
      def self.create_tags_table(db)
        db.execute <<~SQL
          CREATE TABLE tags (
            name TEXT PRIMARY KEY
          )
        SQL
      end

      # Create doc_tags table
      #
      # @param db [SQLite3::Database] Database connection
      def self.create_doc_tags_table(db)
        db.execute <<~SQL
          CREATE TABLE doc_tags (
            doc_id TEXT,
            tag TEXT,
            PRIMARY KEY (doc_id, tag)
          )
        SQL
      end

      # Create chunks FTS5 virtual table
      #
      # @param db [SQLite3::Database] Database connection
      def self.create_chunks_table(db)
        db.execute <<~SQL
          CREATE VIRTUAL TABLE chunks USING fts5(
            chunk_id,
            doc_id,
            title,
            text,
            category,
            tags,
            position,
            tokenize='porter'
          )
        SQL
      end
    end
  end
end
