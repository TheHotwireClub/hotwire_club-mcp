# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "standard/rake"

task default: [:test, :standard]

namespace :kb do
  namespace :build do
    desc "Build the knowledge base from corpus directory (all ready documents)"
    task :pro do
      require_relative "lib/hotwire_club/mcp"

      HotwireClub::MCP::ProBuilder.run("corpus", "db/kb-pro.sqlite")
      puts "Knowledge base built successfully with all ready documents!"
    end

    desc "Build the knowledge base from corpus directory (free documents only)"
    task :free do
      require_relative "lib/hotwire_club/mcp"

      HotwireClub::MCP::FreeBuilder.run("corpus", "db/kb.sqlite")
      puts "Knowledge base built successfully with free documents only!"
    end
  end
end

# Hook kb:build:free into the build task (for releases)
Rake::Task[:build].enhance(["kb:build:free"])

namespace :build do
  desc "Build the knowledge base with all ready documents (pro + free) and then build the gem with -pro suffix"
  task pro: ["kb:build:pro"] do
    require "bundler/gem_helper"
    require "fileutils"

    original_gemspec_path = "hotwire_club-mcp.gemspec"
    backup_gemspec_path = "#{original_gemspec_path}.backup"
    temp_gemspec_path = "hotwire_club-mcp-pro.gemspec"

    begin
      # Copy original gemspec to backup (safety net)
      FileUtils.cp(original_gemspec_path, backup_gemspec_path)

      # Read original and create modified version
      original_gemspec = File.read(original_gemspec_path)
      pro_gemspec_content = original_gemspec.gsub('spec.name = "hotwire_club-mcp"',
                                                  'spec.name = "hotwire_club-mcp-pro"')
                                            .gsub('"db", "kb.sqlite"', '"db", "kb-pro.sqlite"')
                                            .gsub('"db/kb.sqlite"', '"db/kb-pro.sqlite"')
                                            # Explicitly remove free database file from spec.files (in case it's tracked in git)
                                            .gsub(/spec\.files << "db\/kb-pro\.sqlite" if File\.exist\?\(db_path\)\n/,
                                                  "spec.files.reject! { |f| f == \"db/kb.sqlite\" }\n  spec.files << \"db/kb-pro.sqlite\" if File.exist?(db_path)\n")

      # Verify replacement worked
      unless pro_gemspec_content.include?('"db", "kb-pro.sqlite"') && pro_gemspec_content.include?('"db/kb-pro.sqlite"')
        raise "Failed to replace database paths in gemspec"
      end

      # Write modified version to temp file, then move it to original location
      File.write(temp_gemspec_path, pro_gemspec_content)
      FileUtils.mv(temp_gemspec_path, original_gemspec_path)

      # Use GemHelper to build (it will use the modified gemspec)
      helper = Bundler::GemHelper.new(Dir.pwd)
      helper.build_gem
    ensure
      # Always restore original gemspec from backup
      FileUtils.mv(backup_gemspec_path, original_gemspec_path) if File.exist?(backup_gemspec_path)
      # Clean up any leftover temp file
      FileUtils.rm_f(temp_gemspec_path)
    end
  end
end
