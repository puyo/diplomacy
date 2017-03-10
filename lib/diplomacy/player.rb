module Diplomacy
  # An agent capable of responding to requests for orders.
  class Player
    # Prompt, notifying the player that there is a new game state
    # to examine and submit orders for.
    def request_orders(game, power)
      raise Error, "Player#request_orders must be implemented in class #{self.class}"
    end
  end

  # An artificial intelligence player.
  class AI < Player
  end

  # A human player.
  class Human < Player
    def request_orders(game, power)
      # email?
    end
  end
end

require_relative './dopeybot'
require_relative './holdbot'
