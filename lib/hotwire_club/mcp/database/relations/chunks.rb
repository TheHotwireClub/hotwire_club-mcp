# frozen_string_literal: true

module HotwireClub
  module MCP
    module Database
      class Chunks < ROM::Relation[:sql]
        # no infer, define explicitly
        schema(:chunks, infer: false) do
          attribute :chunk_id,  ROM::SQL::Types::String
          attribute :doc_id,    ROM::SQL::Types::String
          attribute :title,     ROM::SQL::Types::String
          attribute :text,      ROM::SQL::Types::String
          attribute :category,  ROM::SQL::Types::String.optional
          attribute :tags,      ROM::SQL::Types::String.optional
          attribute :position,  ROM::SQL::Types::Integer
        end

        auto_struct true

        # FTS5 full-text search
        #
        # @param term [String] Search term
        # @return [ROM::SQL::Relation] Relation filtered by FTS5 search
        def full_text_search(term)
          new(dataset.where(Sequel.lit("chunks MATCH ?", term)))
        end
      end
    end
  end
end
