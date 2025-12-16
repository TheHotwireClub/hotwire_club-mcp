# frozen_string_literal: true

module HotwireClub
  module MCP
    module Database
      class TagsRepo < ROM::Repository[:tags]
        # Get all tags with their document counts
        #
        # @return [Array] Array of tags with count attribute (as hashes, not structs)
        def all_with_counts
          # Build query using dataset directly and return as hashes
          # We can't use the tags relation struct because it doesn't have a count attribute
          # Explicitly use container.relations to ensure we're using the correct container
          tags_relation = container.relations[:tags]

          tags_relation.dataset
                       .left_join(:doc_tags, tag: :name)
                       .select(:name, Sequel.as(Sequel.function(:count, Sequel.qualify(:doc_tags, :tag)), :count))
                       .group(:name)
                       .order(:name)
                       .to_a
                       .map { |row| {name: row[:name], count: row[:count] || 0} }
        end

        private

        def doc_tags
          container.relations[:doc_tags]
        end
      end
    end
  end
end
