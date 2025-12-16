# frozen_string_literal: true

require "fast_mcp"
require_relative "database/adapter"
require_relative "tools"

module HotwireClub
  module MCP
    # MCP Server for Hotwire Club knowledge base
    #
    # This server provides MCP tools for searching and browsing the knowledge base.
    # It wraps a FastMcp::Server and registers all the required tools.
    class Server
      # Initialize the MCP server
      #
      # @param container [ROM::Container] ROM container instance
      # @param name [String] Server name (default: "hotwire-club-mcp")
      # @param version [String] Server version (default: HotwireClub::MCP::VERSION)
      def initialize(container:, name: "hotwire-club-mcp", version: VERSION)
        @container = container
        @adapter = Database::Adapter.new(container)
        @fast_mcp_server = ::FastMcp::Server.new(name: name, version: version)
        register_tools
      end

      # Get the underlying FastMcp server instance
      #
      # @return [FastMcp::Server] FastMcp server instance
      attr_reader :fast_mcp_server

      # Start the MCP server (delegates to FastMcp server)
      def start
        @fast_mcp_server.start
      end

      # Get all registered tools
      #
      # @return [Hash] Hash of tool names to tool classes
      def tools
        @fast_mcp_server.tools
      end

      private

      # Register all MCP tools with the server
      def register_tools
        # Register each tool class
        @fast_mcp_server.register_tool(Tools::SearchHwcKbTool)
        @fast_mcp_server.register_tool(Tools::GetHwcKbChunkTool)
        @fast_mcp_server.register_tool(Tools::ListHwcKbCategoriesTool)
        @fast_mcp_server.register_tool(Tools::ListHwcKbTagsTool)
        @fast_mcp_server.register_tool(Tools::ListHwcKbDocsTool)
        @fast_mcp_server.register_tool(Tools::RelatedHwcKbDocsTool)

        # Set adapter reference for tools that need it
        [Tools::SearchHwcKbTool, Tools::GetHwcKbChunkTool, Tools::ListHwcKbCategoriesTool,
         Tools::ListHwcKbTagsTool, Tools::ListHwcKbDocsTool, Tools::RelatedHwcKbDocsTool].each do |tool_class|
          tool_class.adapter = @adapter if tool_class.respond_to?(:adapter=)
        end
      end
    end
  end
end
