require_relative './player'
require_relative './game'

class HoldBot < Diplomacy::AI
  def request_orders(game, power)
    power.submit_orders("")
  end
end

