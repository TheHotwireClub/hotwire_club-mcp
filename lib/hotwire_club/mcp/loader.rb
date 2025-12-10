# frozen_string_literal: true

require "pathname"

module HotwireClub
  module MCP
    # Loader class for knowledge base documents
    class Loader
      # Load all documents from corpus directory
      #
      # @return [Array<Doc>] Array of Doc objects for files with ready: true
      def self.load_docs(corpus_path = "corpus")
        corpus_dir = Pathname.new(corpus_path)
        return [] unless corpus_dir.directory?

        corpus_dir.glob("*.md")
          .map { |file| Doc.from_file(file.to_s) }
          .compact
      end
    end
  end
end
