# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "standard/rake"

task default: [:test, :standard]

namespace :kb do
  desc "Build the knowledge base from corpus directory"
  task :build do
    require_relative "lib/hotwire_club/mcp"

    HotwireClub::MCP::Builder.run("corpus", "db/kb.sqlite")
    puts "Knowledge base built successfully!"
  end
end

# Hook kb:build into the build task
Rake::Task[:build].enhance(["kb:build"])
