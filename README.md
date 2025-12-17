# HotwireClub::Mcp

MCP server for Hotwire Club knowledge base - provides search_hotwire_kb, list_kb_categories, list_kb_tags, and list_kb_docs tools/resources.

A Model Context Protocol (MCP) server that provides access to the Hotwire Club knowledge base. Builds a searchable SQLite database from markdown documents and exposes MCP tools and resources for searching and browsing documentation, categories, tags, and documents.

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

## Usage

Run the MCP server:

```bash
hwc-mcp
```

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
