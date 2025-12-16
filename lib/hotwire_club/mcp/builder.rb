# frozen_string_literal: true

require "sqlite3"
require "date"
require_relative "schema"
require_relative "loader"
require_relative "chunker"

module HotwireClub
  module MCP
    # Builder class for knowledge base
    class Builder
      # Build the knowledge base from a corpus directory
      #
      # @param corpus_path [String] Path to the corpus directory
      # @param db_path [String, nil] Optional database path (defaults to Schema::DB_PATH)
      def self.run(corpus_path, db_path = nil)
        db_path ||= Schema::DB_PATH

        # 1. Create fresh database
        Schema.create!(db_path)

        # 2. Load documents
        docs = Loader.load_docs(corpus_path)

        # 3. Chunk documents
        chunks = Chunker.chunk_docs(docs)

        # 4. Insert into DB in one transaction
        db = SQLite3::Database.new(db_path)

        db.transaction do
          insert_docs(db, docs)
          insert_tags(db, docs)
          insert_doc_tags(db, docs)
          insert_chunks(db, chunks)
        end

        db.close
      end

      # Convert date to string format for database storage
      #
      # @param date [Date, String, nil] Date value to convert
      # @return [String, nil] ISO8601 formatted date string or original string/nil
      def self.format_date_for_db(date)
        return nil if date.nil?

        if date.is_a?(Date)
          date.iso8601
        elsif date.is_a?(String)
          date
        else
          date.to_s
        end
      end

      # Insert documents into database
      #
      # @param db [SQLite3::Database] Database connection
      # @param docs [Array<Doc>] Documents to insert
      def self.insert_docs(db, docs)
        docs.each do |doc|
          date_value = format_date_for_db(doc.date)

          db.execute(
            "INSERT INTO docs (id, title, category, summary, body, date) VALUES (?, ?, ?, ?, ?, ?)",
            [doc.id, doc.title, doc.category, doc.summary, doc.body, date_value],
          )
        end
      end

      # Insert unique tags into database
      #
      # @param db [SQLite3::Database] Database connection
      # @param docs [Array<Doc>] Documents to extract tags from
      def self.insert_tags(db, docs)
        all_tags = docs.flat_map(&:tags).uniq

        all_tags.each do |tag|
          db.execute("INSERT OR IGNORE INTO tags (name) VALUES (?)", [tag])
        end
      end

      # Insert document-tag relationships into database
      #
      # @param db [SQLite3::Database] Database connection
      # @param docs [Array<Doc>] Documents to extract relationships from
      def self.insert_doc_tags(db, docs)
        docs.each do |doc|
          doc.tags.each do |tag|
            db.execute("INSERT INTO doc_tags (doc_id, tag) VALUES (?, ?)", [doc.id, tag])
          end
        end
      end

      # Insert chunks into database with comma-joined tags
      #
      # @param db [SQLite3::Database] Database connection
      # @param chunks [Array<Chunk>] Chunks to insert
      def self.insert_chunks(db, chunks)
        chunks.each do |chunk|
          comma_joined_tags = chunk.tags.join(",")
          insert_sql = "INSERT INTO chunks (chunk_id, doc_id, title, text, category, tags, position) " \
                       "VALUES (?, ?, ?, ?, ?, ?, ?)"

          db.execute(
            insert_sql,
            [chunk.id, chunk.doc_id, chunk.title, chunk.text, chunk.category, comma_joined_tags, chunk.position],
          )
        end
      end
    end
  end
end
