# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "rom"

module HotwireClub
  class TestDatabase < Minitest::Test
    def setup
      @db_path = File.join(Dir.pwd, "db", "kb-test.sqlite")
      @db_dir = File.dirname(@db_path)
      FileUtils.mkdir_p(@db_dir)
    end

    def teardown
      FileUtils.rm_f(@db_path)
      FileUtils.rmdir(@db_dir) if Dir.exist?(@db_dir) && Dir.empty?(@db_dir)
    end

    def test_container_returns_rom_container
      # Create the database schema first
      HotwireClub::MCP::Schema.create!(@db_path)

      container = HotwireClub::MCP::Database.container(@db_path)

      assert_instance_of ROM::Container, container
    end

    def test_container_uses_default_db_path_when_nil
      default_path = HotwireClub::MCP::Schema::DB_PATH
      FileUtils.mkdir_p(File.dirname(default_path))
      HotwireClub::MCP::Schema.create!(default_path)

      container = HotwireClub::MCP::Database.container(nil)

      assert_instance_of ROM::Container, container

      # Cleanup
      FileUtils.rm_f(default_path)
    end

    def test_container_uses_custom_db_path
      HotwireClub::MCP::Schema.create!(@db_path)

      container = HotwireClub::MCP::Database.container(@db_path)

      assert_instance_of ROM::Container, container
    end

    def test_container_has_sql_gateway
      HotwireClub::MCP::Schema.create!(@db_path)

      container = HotwireClub::MCP::Database.container(@db_path)

      assert container.gateways[:default]
      assert_instance_of ROM::SQL::Gateway, container.gateways[:default]
    end
  end
end
