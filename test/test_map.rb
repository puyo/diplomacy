require_relative '../lib/diplomacy/map'
require 'test/unit'

# Tests for Map.
class MapTest < Test::Unit::TestCase
  include Diplomacy

  @@map = Map.new("standard")

  attr :map

  def setup
    @map = @@map
  end

  def test_homes
    england = map.first_turn.power(map.power_definition("e"))
    homes = map.power_definition("e").homes
    assert homes.size == 3
    homes.each do |home|
      assert england.home?(home)
    end
  end

  def test_parse_province
    assert_nothing_raised do
      map.parse_province("St. Petersburg")
    end
    assert_equal map.parse_province("St. Petersburg").name, "St. Petersburg"
  end
  def test_parse_area
    assert_equal map.parse_area("a tus").label, "Tuscany"
    assert_equal map.parse_area("St. Petersburg South Coast").label, "St. Petersburg, South Coast"
    assert_equal map.parse_area("St. Petersburg/sc").label, "St. Petersburg, South Coast"
    assert_equal map.parse_area("St. Petersburgsc").label, "St. Petersburg, South Coast"
    assert_equal map.parse_area("St. Petersburgsc").label, "St. Petersburg, South Coast"
    assert_equal map.parse_area("StPsc").label, "St. Petersburg, South Coast"
    assert_equal map.parse_area("StP/sc").label, "St. Petersburg, South Coast"
    assert_equal map.parse_area("StP(sc)").label, "St. Petersburg, South Coast"
    assert_equal map.parse_area("StP(south coast)").label, "St. Petersburg, South Coast"
    assert_equal map.parse_area("StP(south)").label, "St. Petersburg, South Coast"
    assert_equal map.parse_area("StP_sc").label, "St. Petersburg, South Coast"
    assert_equal map.parse_area("St. Petersburg South Coast").key, 'sc'
    assert_raises Diplomacy::Error, "Did not raise error on ambiguous text" do
      area = map.parse_area("rum")
    end
  end

  #	def test_area_piece
  #		area = map.area("ven", "a")
  #		assert(area && area.piece && area.piece.type == "a")
  #	end

  #	def test_area_pieces_differ
  #		area1 = @@map.area("edi", "f")
  #		area2 = @@map.area("lpl", "f")
  #		assert_not_equal(area1, area2)
  #	end
end
