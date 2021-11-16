require "test/unit"
require_relative "core_assertions"

class Test::Unit::TestCase
  alias skip pend
end

Test::Unit::TestCase.include Test::Unit::CoreAssertions
