# frozen_string_literal: true

require "sqlite3"
require "fileutils"

module HotwireClub
  module MCP
    class Schema
      DB_PATH = File.join(Dir.pwd, "db", "kb.sqlite")

      def self.create!
        db_dir = File.dirname(DB_PATH)
        FileUtils.mkdir_p(db_dir)
        FileUtils.rm_f(DB_PATH)

        db = SQLite3::Database.new(DB_PATH)

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

        db.execute <<~SQL
          CREATE TABLE tags (
            name TEXT PRIMARY KEY
          )
        SQL

        db.execute <<~SQL
          CREATE TABLE doc_tags (
            doc_id TEXT,
            tag TEXT,
            PRIMARY KEY (doc_id, tag)
          )
        SQL

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

        db.close
      end
    end
  end
end
