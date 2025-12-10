# frozen_string_literal: true

require "front_matter_parser"
require "date"
require "psych"

# Configure Psych to allow Date class (required for Psych 5.x)
# Psych 5.x uses a restricted class loader that blocks Date by default
# Patch the restricted class loader to allow Date, Time, DateTime
if defined?(Psych) && Psych::VERSION >= "5.0" && defined?(Psych::ClassLoader::Restricted)
  Psych::ClassLoader::Restricted.class_eval do
    alias_method :original_find, :find
    def find(name)
      case name
      when "Date"
        Date
      when "Time"
        Time
      when "DateTime"
        DateTime
      else
        original_find(name)
      end
    end
  end
end

module HotwireClub
  module MCP
    # Data class representing a single document
    Doc = Data.define(:id, :title, :category, :tags, :body, :summary, :date) {
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

        # Extract date from front matter
        date = front_matter["date"]

        new(
          id:       nil,
          title:    title,
          category: category,
          tags:     tags,
          body:     body,
          summary:  summary,
          date:     date,
        )
      end
    }
  end
end
