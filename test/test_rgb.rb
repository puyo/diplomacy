require 'test/unit'
require_relative '../lib/diplomacy/rgb'

class RGBTest < Test::Unit::TestCase
  def test_new
    assert_equal RGB.new("#ffffff"), RGB.new(255, 255, 255)
  end
end
