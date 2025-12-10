# frozen_string_literal: true

require "test_helper"

module HotwireClub
  class TestMcp < Minitest::Test
    def test_that_it_has_a_version_number
      refute_nil ::HotwireClub::MCP::VERSION
    end

    # def test_it_does_something_useful
    #   assert false
    # end
  end
end
