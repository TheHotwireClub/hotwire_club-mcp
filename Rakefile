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

      HotwireClub::MCP::ProBuilder.run("corpus", "db/kb.sqlite")
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
  desc "Build the knowledge base with all ready documents (pro + free) and then build the gem"
  task :pro do
    Rake::Task["kb:build:pro"].invoke
    Rake::Task["build"].invoke
  end
end
