# frozen_string_literal: true

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
      # Generate a stable document ID from a title
      #
      # @param title [String] The document title
      # @return [String] A slugified version of the title suitable for use as an ID
      def self.id_from_title(title)
        return nil if title.nil? || title.empty?

        # Convert to lowercase, replace spaces and underscores with hyphens,
        # remove special characters (keep alphanumeric and hyphens), collapse multiple hyphens
        title.downcase
             .gsub(%r{[\s_]+}, "-")
             .gsub(%r{[^a-z0-9-]}, "")
             .gsub(%r{-+}, "-")
             .gsub(%r{^-|-$}, "")
      end

      def self.from_file(file_path)
        require "front_matter_parser"
        parsed = FrontMatterParser::Parser.parse_file(file_path)
        front_matter = parsed.front_matter

        # Only process files with ready: true
        return nil unless front_matter["ready"] == true

        title = extract_title(front_matter, file_path)
        id = id_from_title(title)
        category = extract_category(front_matter)
        tags = Array(front_matter["tags"])
        body = parsed.content
        summary = extract_summary(front_matter, body)
        date = front_matter["date"]

        new(
          id:       id,
          title:    title,
          category: category,
          tags:     tags,
          body:     body,
          summary:  summary,
          date:     date,
        )
      end

      # Extract title from front matter or filename
      #
      # @param front_matter [Hash] Front matter hash
      # @param file_path [String] File path
      # @return [String] Document title
      def self.extract_title(front_matter, file_path)
        front_matter["title"] || File.basename(file_path, ".md")
      end

      # Extract category from front matter
      #
      # @param front_matter [Hash] Front matter hash
      # @return [String, nil] Category or nil
      def self.extract_category(front_matter)
        front_matter["categories"]&.first || front_matter["category"]
      end

      # Extract summary from front matter or body
      #
      # @param front_matter [Hash] Front matter hash
      # @param body [String] Document body
      # @return [String] Summary text
      def self.extract_summary(front_matter, body)
        front_matter["description"] || body.split("\n\n").first
      end
    }
  end
end
