require "test/unit"
require "core_assertions"

class Test::Unit::TestCase
  alias skip pend
end

Test::Unit::TestCase.include Test::Unit::CoreAssertions
