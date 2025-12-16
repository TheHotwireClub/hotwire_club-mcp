# frozen_string_literal: true

require "rom"
require "rom-sql"
require "uri"
require_relative "schema"

module HotwireClub
  module MCP
    # Database module for ROM container setup
    module Database
      # Create and configure ROM container
      #
      # @param db_path [String, nil] Database path (defaults to Schema::DB_PATH)
      # @return [ROM::Container] Configured ROM container
      def self.container(db_path = nil)
        db_path ||= Schema::DB_PATH
        # Use absolute path with three slashes for SQLite URI format
        # URI encode the path to handle spaces and special characters
        absolute_path = File.expand_path(db_path)
        encoded_path = URI::RFC2396_PARSER.escape(absolute_path)
        sqlite_uri = "sqlite:///#{encoded_path}"

        ROM.container(:sql, sqlite_uri) do |config|
          config.auto_registration(
            File.join(__dir__, "database"),
            namespace: "HotwireClub::MCP::Database",
          )
        end
      end
    end
  end
end
