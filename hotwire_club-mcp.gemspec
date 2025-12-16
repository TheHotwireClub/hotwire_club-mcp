# frozen_string_literal: true

require_relative "lib/hotwire_club/mcp/version"

Gem::Specification.new do |spec|
  spec.name = "hotwire_club-mcp"
  spec.version = HotwireClub::MCP::VERSION
  spec.authors = ["Julian Rubisch"]
  spec.email = ["julian@julianrubisch.at"]

  spec.summary = "MCP server for Hotwire Club knowledge base - provides search_hotwire_kb, list_kb_categories, list_kb_tags, and list_kb_docs tools/resources"
  spec.description = "A Model Context Protocol (MCP) server that provides access to the Hotwire Club knowledge base. Builds a searchable SQLite database from markdown documents and exposes MCP tools and resources for searching and browsing documentation, categories, tags, and documents."
  spec.homepage = "https://github.com/julianrubisch/hotwire_club-mcp"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "front_matter_parser", "~> 1.0"
  spec.add_dependency "sqlite3", "~> 2.0"

  spec.add_development_dependency "minitest", "~> 5.16"
  spec.add_development_dependency "rubocop", "~> 1.0"
  spec.add_development_dependency "rubocop-minitest", "~> 0.38"
  spec.add_development_dependency "rubocop-rake", "~> 0.7"
end
