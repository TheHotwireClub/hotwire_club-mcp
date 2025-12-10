# frozen_string_literal: true

require "front_matter_parser"

module HotwireClub
  module MCP
    # Data class representing a single document
    Doc = Data.define(:id, :title, :category, :tags, :body, :summary) {
      def self.from_file(file_path)
        parsed = FrontMatterParser::Parser.parse_file(file_path)
        front_matter = parsed.front_matter

        # Only process files with ready: true
        return nil unless front_matter["ready"] == true

        # Infer title from front matter
        title = front_matter["title"] || File.basename(file_path, ".md")

        # Infer category from front matter (take first category or nil)
        category = front_matter["categories"]&.first || front_matter["category"]

        # Normalize tags to Array
        tags = Array(front_matter["tags"])

        # Body is the content after front matter
        body = parsed.content

        # Summary can be from description or first paragraph
        summary = front_matter["description"] || body.split("\n\n").first

        new(
          id:       nil,
          title:    title,
          category: category,
          tags:     tags,
          body:     body,
          summary:  summary,
        )
      end
    }
  end
end
