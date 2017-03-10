require_relative './order'

module Diplomacy
  # An order for a piece.
  class PieceOrder < Order
    # --- Class ------------------------------

    def initialize(turn, piece)
      super(turn)
      @piece = piece
    end

    # --- Queries ----------------------------

    def check
      log "#{@piece}: Checking order..."
      @results.clear
      check_bounces

      if bounced?
        log "#{@piece}: Checking for opponents back home which may now fail..."
        @turn.opponents(@piece.area.province, @piece).each do |op|
          op.order.check if op.order.successful?
        end
      end
      check_disruptions
      @checked = true
    end

    def execute(next_turn)
      if dislodged?
        log "#{piece}: Dislodged..."
        next_turn.copy_piece_dislodged(piece, piece.area)
      else
        log "#{piece}: Staying in #{piece.area}..."
        next_turn.copy_piece_to(piece, piece.area)
      end
    end
  end
end

require_relative './moveorder'
require_relative './holdorder'
require_relative './supportorder'
require_relative './convoyorder'
