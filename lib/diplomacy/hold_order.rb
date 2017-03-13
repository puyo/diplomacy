require_relative './piece_order'

module Diplomacy
  class HoldOrder < PieceOrder
    # --- Class ------------------------------

    REGEXP = /^(.*) (?:h|hold|holds)$/

    def initialize(turn:, piece:)
      super(turn: turn, piece: piece)
    end

    def self.parse(power, match_data, mine = true)
      piece = power.turn.parse_piece(power, match_data[1], mine)
      new(turn: power.turn, piece: piece)
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
