# HotwireClub::Mcp

MCP server for Hotwire Club knowledge base - provides tools for searching, browsing, and discovering documentation from the Hotwire Club knowledge base.

A Model Context Protocol (MCP) server that provides access to the Hotwire Club knowledge base. Builds a searchable SQLite database from markdown documents and exposes MCP tools for searching and browsing documentation, categories, tags, and documents.

## Features

The server provides the following MCP tools:

- **SearchHwcKbTool** - Search the knowledge base for chunks matching a query with optional category and tag filters
- **GetHwcKbChunkTool** - Retrieve a single knowledge base chunk by its chunk_id
- **ListHwcKbCategoriesTool** - List all unique categories available in the knowledge base
- **ListHwcKbTagsTool** - List all tags available in the knowledge base
- **ListHwcKbDocsTool** - List documents with optional filtering by category and tags, with pagination support
- **RelatedHwcKbDocsTool** - Find documents related to a given document or chunk based on shared categories and tags

The knowledge base is pre-built and included in the gem, so no additional setup is required after installation.

## Installation

Install the gem:

```bash
gem install hotwire_club-mcp
```

**Important:** After installing, if you're using `rbenv`, you might need to regenerate the shims so the `hwc-mcp` executable is available:

```bash
rbenv rehash
```

If you encounter an error like "cannot rehash: /Users/username/.rbenv/shims/.rbenv-shim exists", remove the lock file and try again:

```bash
rm -f ~/.rbenv/shims/.rbenv-shim
rbenv rehash
```

## Requirements

- Ruby 3.2.0 or higher
- SQLite3

## Usage

Run the MCP server:

```bash
hwc-mcp
```

The server uses a pre-built SQLite database (`db/kb.sqlite`) that is included with the gem. No additional configuration or database setup is required.

### Configuration

#### Claude

```json
{
  "mcpServers": {
    "hotwire-club-mcp": {
      "command": "hwc-mcp",
      "args": []
    }
  }
}
```

#### Cursor

```json
{
  "mcpServers": {
    "hotwire-club-mcp": {
      "command": "hwc-mcp",
      "args": []
    }
  }
}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/julianrubisch/hotwire_club-mcp.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
