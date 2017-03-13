require_relative './piece_order'

module Diplomacy
  class RetreatOrder < PieceOrder
    # --- Class ------------------------------

    REGEXP = /^([^-]+)-([^-]+)$/

    def initialize(turn:, piece:, destination:)
      super(turn: turn, piece: piece)
      @destination = destination
    end

    def self.parse(power, match_data, mine = true)
      piece = power.turn.parse_dislodged_piece(power, match_data[1], mine)
      destination = power.turn.map.parse_area(match_data[2], piece.type)
      new(turn: power.turn, piece: piece, destination: destination)
    end

    # --- Queries ----------------------------

    attr_reader :destination

    def string
      "#{piece} - #{destination}"
    end

    def text
      "#{piece.id.upcase} - #{destination.location.upcase}"
    end

    # --- Commands ---------------------------

    def execute(next_turn)
      if successful?
        Util.log "#{piece}: Retreating to #{destination}..."
        next_turn.copy_piece_to(piece, destination)
      else
        Util.log "#{piece}: Not adding piece to next turn..."
        # Do not add piece to next turn.
      end
    end

    def unreachable?
      !@piece.area.connections.include?(@destination)
    end

    def cannot_retreat_there?
      !@piece.retreats.include?(@destination)
    end

    def validate
      if unreachable?
        Util.log "Piece #{@piece} cannot retreat to #{@destination} because that is impossible"
        add_result(IMPOSSIBLE)
      end
      if cannot_retreat_there?
        Util.log "Piece #{@piece} cannot retreat to #{@destination}"
        add_result(IMPOSSIBLE)
      end
    end
  end
end
