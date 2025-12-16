# frozen_string_literal: true

require "fast_mcp"

module HotwireClub
  module MCP
    module Tools
      # Base class for all MCP tools
      #
      # Provides common functionality like adapter access for all tools.
      class BaseTool < ::MCP::Tool
        class << self
          attr_accessor :adapter
        end

        protected

        # Get the adapter instance
        #
        # @return [Database::Adapter] Adapter instance
        # @raise [RuntimeError] if adapter is not set
        def adapter
          raise "Adapter not set" unless self.class.adapter

          self.class.adapter
        end
      end
    end
  end
end
