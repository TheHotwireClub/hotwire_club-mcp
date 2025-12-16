# frozen_string_literal: true

module HotwireClub
  module MCP
    module Database
      class Tags < ROM::Relation[:sql]
        schema(:tags, infer: true)

        auto_struct true
      end
    end
  end
end
