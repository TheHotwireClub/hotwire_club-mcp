# frozen_string_literal: true

module HotwireClub
  module MCP
    module Database
      class Docs < ROM::Relation[:sql]
        schema(:docs, infer: true)

        auto_struct true
      end
    end
  end
end
