require_relative './pieceorder'

module Diplomacy
  class HoldOrder < PieceOrder
    # --- Class ------------------------------

    REGEXP = /^(.*) (?:h|hold|holds)$/

    def initialize(turn, piece)
      super(turn, piece)
    end

    def self.parse(power, match_data, mine=true)
      piece = power.turn.parse_piece(power, match_data[1], mine)
      HoldOrder.new(power.turn, piece)
    end

    # --- Queries ----------------------------

    def destination
      @piece.area
    end

    def string
      "#{@piece} HOLD"
    end

    def text
      "#{@piece.id.upcase} HOLD"
    end
  end
end
