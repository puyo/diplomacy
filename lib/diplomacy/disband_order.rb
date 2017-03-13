require_relative './piece_order'

module Diplomacy
  class DisbandOrder < PieceOrder
    # --- Class ------------------------------

    REGEXP = /^(?:disband|d) (.*)$/

    def initialize(turn:, piece:)
      super(turn: turn, piece: piece)
    end

    def self.parse(power, match_data, _mine = true)
      begin
        piece = power.turn.parse_dislodged_piece(power, match_data[1], true)
      rescue
        piece = power.turn.parse_piece(power, match_data[1], true)
      end
      new(turn: power.turn, piece: piece)
    end

    def power
      @piece.owner
    end

    # --- Queries ----------------------------

    def string
      "DISBAND #{@piece}"
    end

    def text
      "DISBAND #{@piece.id}"
    end

    def execute(next_turn)
      Util.log "#{piece}: Executing order..."
      next_turn.remove_piece(piece)
    end
  end
end
