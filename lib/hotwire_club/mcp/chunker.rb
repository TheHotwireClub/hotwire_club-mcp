# frozen_string_literal: true

require_relative "chunk"

module HotwireClub
  module MCP
    # Chunker class for splitting documents into chunks
    class Chunker
      TARGET_SIZE = 2000
      MAX_SIZE = 3500

      # Chunk documents into smaller pieces
      #
      # @param docs [Array<Doc>] Array of Doc objects to chunk
      # @return [Array<Chunk>] Array of Chunk objects
      def self.chunk_docs(docs)
        chunks = []
        docs.each do |doc|
          doc_chunks = chunk_doc(doc)
          chunks.concat(doc_chunks)
        end
        chunks
      end

      # Chunk a single document
      #
      # @param doc [Doc] Document to chunk
      # @return [Array<Chunk>] Array of Chunk objects for this document
      def self.chunk_doc(doc)
        sections = split_by_headings(doc.body)
        chunks = []
        position = 0

        sections.each do |section|
          section_chunks = split_by_size(section[:text], section[:title])
          section_chunks.each do |chunk_text|
            chunks << Chunk.new(
              id:       nil,
              doc_id:   doc.id,
              title:    section[:title],
              category: doc.category,
              tags:     doc.tags,
              position: position,
              text:     chunk_text,
            )
            position += 1
          end
        end

        chunks
      end

      # Split document body by headings (# and ##)
      #
      # @param body [String] Document body text
      # @return [Array<Hash>] Array of hashes with :title and :text keys
      def self.split_by_headings(body)
        sections = []
        current_section = {title: nil, text: ""}

        body.lines.each do |line|
          if heading?(line)
            sections << current_section.dup if section_has_content?(current_section)
            current_section = new_section_from_heading(line)
          else
            current_section[:text] += line
          end
        end

        sections << current_section if section_has_content?(current_section)
        sections.empty? ? [{title: nil, text: body}] : sections
      end

      # Check if a line is a heading (# or ##)
      #
      # @param line [String] Line to check
      # @return [Boolean] True if line is a heading
      def self.heading?(line)
        line.match?(%r{^##?\s+})
      end

      # Check if a section has content
      #
      # @param section [Hash] Section to check
      # @return [Boolean] True if section has content
      def self.section_has_content?(section)
        section[:text].strip.length.positive?
      end

      # Create a new section from a heading line
      #
      # @param line [String] Heading line
      # @return [Hash] New section hash
      def self.new_section_from_heading(line)
        title = line.sub(%r{^##?\s+}, "").strip
        {title: title, text: line}
      end

      # Split text by size, respecting paragraph boundaries
      #
      # @param text [String] Text to split
      # @param title [String] Title for the chunks
      # @return [Array<String>] Array of text chunks
      def self.split_by_size(text, _title)
        return [text] if text.length <= MAX_SIZE

        chunks = []
        paragraphs = split_into_paragraphs(text)
        current_chunk = ""

        paragraphs.each do |paragraph|
          if paragraph.length > MAX_SIZE
            current_chunk = handle_oversized_paragraph(paragraph, current_chunk, chunks)
          elsif should_start_new_chunk?(current_chunk, paragraph)
            chunks << current_chunk.strip
            current_chunk = paragraph
          else
            current_chunk += paragraph
          end
        end

        chunks << current_chunk.strip if current_chunk.strip.length.positive?
        chunks
      end

      # Handle an oversized paragraph by splitting it
      #
      # @param paragraph [String] Paragraph that exceeds MAX_SIZE
      # @param current_chunk [String] Current chunk being built
      # @param chunks [Array<String>] Array of completed chunks
      # @return [String] Remaining chunk text
      def self.handle_oversized_paragraph(paragraph, current_chunk, chunks)
        chunks << current_chunk.strip if current_chunk.strip.length.positive?

        paragraph_chunks = split_oversized_paragraph(paragraph)
        chunks.concat(paragraph_chunks[0..-2]) # Add all but the last
        paragraph_chunks.last || ""
      end

      # Determine if a new chunk should be started
      #
      # @param current_chunk [String] Current chunk being built
      # @param paragraph [String] Next paragraph to add
      # @return [Boolean] True if a new chunk should be started
      def self.should_start_new_chunk?(current_chunk, paragraph)
        return false unless current_chunk.length.positive?

        exceeds_max = (current_chunk.length + paragraph.length) > MAX_SIZE
        near_target = current_chunk.length >= TARGET_SIZE && paragraph.length > (MAX_SIZE - TARGET_SIZE)

        exceeds_max || near_target
      end

      # Split an oversized paragraph by sentences or at word boundaries
      #
      # @param paragraph [String] Paragraph that exceeds MAX_SIZE
      # @return [Array<String>] Array of text chunks
      def self.split_oversized_paragraph(paragraph)
        chunks = []
        remaining = paragraph

        while remaining.length > MAX_SIZE
          # Try to split at sentence boundaries first
          # Look for sentence endings followed by space
          split_pos = remaining[0..MAX_SIZE].rindex(%r{[.!?]\s+})

          # If no sentence boundary found, try word boundary
          split_pos = remaining[0..MAX_SIZE].rindex(%r{\s+}) if split_pos.nil?

          # If still no good split point, force split at MAX_SIZE
          split_pos ||= MAX_SIZE

          chunks << remaining[0..split_pos].strip
          remaining = remaining[(split_pos + 1)..] || ""
        end

        chunks << remaining.strip if remaining.strip.length.positive?

        chunks
      end

      # Split text into paragraphs (double newline separated)
      #
      # @param text [String] Text to split
      # @return [Array<String>] Array of paragraphs
      def self.split_into_paragraphs(text)
        # Split by double newlines, preserving them
        paragraphs = text.split(%r{(\n\n+)})
        # Recombine separators with following content
        result = []
        paragraphs.each_slice(2) do |content, separator|
          if separator
            result << (content + separator)
          elsif content&.length&.positive?
            result << content
          end
        end
        result
      end
    end
  end
end
