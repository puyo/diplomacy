require_relative '../../lib/diplomacy/map'
require_relative '../../lib/diplomacy/game'
require_relative '../drawmap'
require 'test/unit'

class DrawTest < Test::Unit::TestCase
  include Diplomacy

  def setup
    @game = Game.new(name: 'test')
    @game.start(false, false)
    Util.log "----------------------------------------------------------"
    Util.log "----------------------------------------------------------"
    Util.log "----------------------------------------------------------"
    Util.log method_name
    Util.log "----------------------------------------------------------"
    Util.log "----------------------------------------------------------"
    Util.log "----------------------------------------------------------"
  end

  attr_reader :game, :map

  def austria; turn.power(map.power_definition("a")) end
  def england; turn.power(map.power_definition("e")) end
  def france; turn.power(map.power_definition("f")) end
  def germany; turn.power(map.power_definition("g")) end
  def italy; turn.power(map.power_definition("i")) end
  def russia; turn.power(map.power_definition("r")) end
  def turkey; turn.power(map.power_definition("t")) end

  def map
    @game.map
  end

  def turn
    @game.turn
  end

  def previous_turn
    @game.previous_turn
  end

  def history
    game.turns.map{|t| t.inspect}.join("\n-----\n")
  end

  def test_draw
    england.submit_orders %{
      F Edi - Nth
      A Lvp - yor
      F Lon h
    }
    austria.submit_orders %{
      A vie - tyl
      f tri-alb
      a bud-rum
    }
    russia.submit_orders %{
      a mos-ukr
      a war s a mos-ukr
    }
    france.submit_orders %{
      a par s f bre h
      f bre h
    }
    game.judge
    game.reoutput_turn_image(game.previous_turn)

    england.submit_orders %{
      F nth c a yor-nor
      a yor -nth-nor
      f lon h
    }

    game.judge
    game.reoutput_turn_image(game.previous_turn)
  end
end
