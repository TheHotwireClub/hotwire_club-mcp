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
        docs.flat_map { |doc| chunk_doc(doc) }
      end

      # Chunk a single document
      #
      # @param doc [Doc] Document to chunk
      # @return [Array<Chunk>] Array of Chunk objects for this document
      def self.chunk_doc(doc)
        pos = -1
        split_by_headings(doc.body).flat_map do |section|
          split_by_size(section[:text], section[:title]).map do |chunk_text|
            Chunk.new(
              id: nil, doc_id: doc.id, title: section[:title],
              category: doc.category, tags: doc.tags,
              position: pos += 1, text: chunk_text
            )
          end
        end
      end

      # Split document body by headings (# and ##)
      #
      # @param body [String] Document body text
      # @return [Array<Hash>] Array of hashes with :title and :text keys
      def self.split_by_headings(body)
        sections = []
        current = {title: nil, text: ""}

        body.lines.each do |line|
          if line.match?(%r{^##?\s+})
            sections << current.dup if current[:text].strip.length.positive?
            current = {title: line.sub(%r{^##?\s+}, "").strip, text: line}
          else
            current[:text] += line
          end
        end

        sections << current if current[:text].strip.length.positive?
        sections.empty? ? [{title: nil, text: body}] : sections
      end

      # Split text by size, respecting paragraph boundaries
      #
      # @param text [String] Text to split
      # @param title [String] Title for the chunks
      # @return [Array<String>] Array of text chunks
      def self.split_by_size(text, _title)
        return [text] if text.length <= MAX_SIZE

        chunks = []
        current = ""

        split_into_paragraphs(text).each do |para|
          if para.length > MAX_SIZE
            current = handle_oversized(para, current, chunks)
          elsif should_split?(current, para)
            chunks << current.strip
            current = para
          else
            current += para
          end
        end

        chunks << current.strip if current.strip.length.positive?
        chunks
      end

      def self.handle_oversized(para, current, chunks)
        chunks << current.strip if current.strip.length.positive?
        para_chunks = split_oversized_paragraph(para)
        chunks.concat(para_chunks[0..-2])
        para_chunks.last || ""
      end

      def self.should_split?(current, para)
        return false unless current.length.positive?

        (current.length + para.length > MAX_SIZE) ||
          (current.length >= TARGET_SIZE && para.length > (MAX_SIZE - TARGET_SIZE))
      end

      # Split an oversized paragraph by sentences or at word boundaries
      #
      # @param paragraph [String] Paragraph that exceeds MAX_SIZE
      # @return [Array<String>] Array of text chunks
      def self.split_oversized_paragraph(paragraph)
        chunks = []
        remaining = paragraph

        while remaining.length > MAX_SIZE
          pos = remaining[0..MAX_SIZE].rindex(%r{[.!?]\s+}) ||
                remaining[0..MAX_SIZE].rindex(%r{\s+}) ||
                MAX_SIZE
          chunks << remaining[0..pos].strip
          remaining = remaining[(pos + 1)..] || ""
        end

        chunks << remaining.strip if remaining.strip.length.positive?
        chunks
      end

      # Split text into paragraphs (double newline separated)
      #
      # @param text [String] Text to split
      # @return [Array<String>] Array of paragraphs
      def self.split_into_paragraphs(text)
        text.split(%r{(\n\n+)}).each_slice(2).filter_map do |content, separator|
          separator ? (content + separator) : (content if content&.length&.positive?)
        end
      end
    end
  end
end
