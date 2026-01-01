# frozen_string_literal: true

require "pathname"

module HotwireClub
  module MCP
    # Loader class for knowledge base documents
    class Loader
      # Load all documents from corpus directory
      #
      # @param corpus_path [String] Path to corpus directory
      # @param free_only [Boolean, nil] If true, only load documents with free: true.
      #   If false or nil, load all ready documents.
      # @return [Array<Doc>] Array of Doc objects for files with ready: true (and optionally free: true)
      def self.load_docs(corpus_path = "corpus", free_only: nil)
        corpus_dir = Pathname.new(corpus_path)
        return [] unless corpus_dir.directory?

        docs = corpus_dir.glob("*.md")
                         .map { |file| Doc.from_file(file.to_s) }
                         .compact

        # Filter by free flag if requested
        if free_only == true
          docs.select { |doc| doc.free == true }
        else
          docs
        end
      end
    end
  end
end
