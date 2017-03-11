require_relative '../lib/diplomacy/game'
require_relative '../lib/diplomacy/util'
require 'test/unit'

class TurnTest < Test::Unit::TestCase
  include Diplomacy

  def setup
    @game = Game.new("test", "standard")
    @game.start(false, false)
    @map = @game.map
    Util.log "----------------------------------------------------------"
    Util.log "----------------------------------------------------------"
    Util.log "----------------------------------------------------------"
    Util.log method_name
    Util.log "----------------------------------------------------------"
    Util.log "----------------------------------------------------------"
    Util.log "----------------------------------------------------------"
  end

  attr_reader :game, :map

  def austria; turn.power(@map.power_definition("a")) end
  def england; turn.power(@map.power_definition("e")) end
  def france; turn.power(@map.power_definition("f")) end
  def germany; turn.power(@map.power_definition("g")) end
  def italy; turn.power(@map.power_definition("i")) end
  def russia; turn.power(@map.power_definition("r")) end
  def turkey; turn.power(@map.power_definition("t")) end

  def turn
    @game.turn
  end

  def previous_turn
    @game.previous_turn
  end

  def history
    game.turns.map{|t| t.inspect}.join("\n-----\n")
  end

  def setup_adjustment
    assert_equal Spring, turn.class
    russia.submit_orders %{
      F Sev-Rum
    }
    game.judge
    assert_equal Autumn, turn.class
    game.judge
    assert_equal AdjustmentTurn, turn.class
    assert_equal previous_turn.power(russia).pieces, russia.pieces
    assert_equal previous_turn.pieces, turn.pieces
    assert_equal 1, turn.number_of_builds(russia.definition), "Russia got the wrong number of builds"
    assert_equal 0, turn.number_of_disbands(russia.definition), "Russia got the wrong number of disbands"
  end

  def setup_disband
    assert_equal Spring, turn.class
    austria.submit_orders %{
      A Vie-Tyl
    }
    game.judge
    assert_equal Autumn, turn.class
    austria.submit_orders %{
      A Tyl-Ven
      F Tri S a Tyl-Ven
    }
    game.judge
    assert_equal RetreatTurn, turn.class
    assert_equal 1, italy.pieces_dislodged.size
    assert_equal 3, austria.pieces.size
    italy.submit_orders %{
      A ven-pie
    }
    game.judge
    assert_equal AdjustmentTurn, turn.class
  end

  def test_build
    setup_adjustment
    russia.submit_orders %{
      B A Sev
    }
    game.judge
    assert_equal previous_turn.power(russia).pieces.size + 1, russia.pieces.size
    assert_equal 1, previous_turn.orders(russia).size
  end

  def test_disband
    setup_disband
    assert_equal AdjustmentTurn, turn.class
    italy.submit_orders %{
      DISBAND A PIE
    }
    game.judge
    assert_equal Spring, turn.class
    assert_equal 2, italy.pieces.size, italy.pieces_all.map{|p| p.inspect}.join(', ')
  end

  def test_only_build_at_home
    setup_adjustment
    russia.submit_orders %{
      B A Spa
    }
    game.judge
    piece = turn.piece("a spa")
    assert piece.nil?, "Russia built in Spain!"
  end

  def test_adjustment_does_not_occur
    assert_equal Spring, turn.class
    turkey.submit_orders %{
      a con-bul
    }
    game.judge
    assert_equal Autumn, turn.class, "a"
    game.judge
    assert_equal AdjustmentTurn, turn.class, "b"
    game.judge
    assert_equal Spring, turn.class, "c"
    game.judge
    assert_equal Autumn, turn.class, "d"
    game.judge
    assert_equal AdjustmentTurn, turn.class, "e"
  end

  def test_adjustment_remove_furthest
    assert_equal Spring, turn.class
    game.judge
    p = russia.make_piece("f nao")
    assert_equal Autumn, turn.class
    game.judge
    assert_equal AdjustmentTurn, turn.class
    assert_equal 0, turn.number_of_builds(russia.definition), "Russia got the wrong number of builds"
    assert_equal 1, turn.number_of_disbands(russia.definition), "Russia got the wrong number of disbands"
    game.judge
    order = previous_turn.orders(russia.definition).find do |o|
      o.class == DisbandOrder and o.piece == p
    end
    assert !order.nil?
  end

  def test_retreat_occurs
    assert_equal Spring, turn.class
    austria.submit_orders %{
      a vie-tyl
    }
    game.judge
    assert_equal Autumn, turn.class
    austria.submit_orders %{
      a tyl-ven
      f tri s a tyl-ven
    }
    game.judge
    assert_equal RetreatTurn, turn.class
    game.judge
  end

  def test_adjustment_after_retreats
    assert_equal Spring, turn.class
    austria.submit_orders %{
      A Vie-Tyl
    }
    game.judge
    assert_equal Autumn, turn.class
    austria.submit_orders %{
      A Tyl-Ven
      F Tri S a Tyl-Ven
    }
    game.judge
    assert_equal RetreatTurn, turn.class
    assert_equal 1, italy.pieces_dislodged.size
    assert_equal 3, austria.pieces.size
    game.judge
    assert_equal AdjustmentTurn, turn.class
  end

  def test_retreats
    assert_equal Spring, turn.class
    austria.submit_orders %{
      A Vie-Tyl
    }
    game.judge
    assert_equal Autumn, turn.class
    austria.submit_orders %{
      A Tyl-Ven
      F Tri S a Tyl-Ven
    }
    game.judge
    assert_equal RetreatTurn, turn.class
    assert_equal 1, italy.pieces_dislodged.size
    assert_equal 3, austria.pieces.size
    italy.submit_orders %{
      a ven-pie
    }
    game.judge
    assert_equal AdjustmentTurn, turn.class
    assert turn.piece("a pie") != nil
  end

  # A real situation in which the "retreat bug" cropped up.
  def test_retreats_2
    turn.clear_pieces
    ia1 = italy.make_piece "a vie"
    ia2 = italy.make_piece "a ven"
    aa1 = austria.make_piece "a tri"
    aa2 = austria.make_piece "a bud"
    ra1 = russia.make_piece "a war"
    ra1 = russia.make_piece "a sil"
    ta1 = turkey.make_piece "a rum"
    ta2 = turkey.make_piece "a ser"

    assert_equal Spring, turn.class
    austria.submit_orders %{
      a tri-vie
      a bud h
    }
    italy.submit_orders %{
      a vie-tri
      a ven s a vie-tri
    }
    turkey.submit_orders %{
      a rum-bud
      a ser s a rum-bud
    }
    russia.submit_orders %{
      a war-gal
      a sil-mun
    }
    game.judge
    assert_equal RetreatTurn, turn.class
    piece = austria.pieces_dislodged.find{|p| p.area == map.parse_area("a bud") }
    assert_equal [map.parse_area("a vie")], piece.retreats
  end
end
