# frozen_string_literal: true

module HotwireClub
  module MCP
    module Database
      class DocTags < ROM::Relation[:sql]
        schema(:doc_tags, infer: true)

        auto_struct true
      end
    end
  end
end
