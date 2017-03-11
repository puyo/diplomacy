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
      Util.log "#{@piece}: Checking order..."
      @results.clear
      check_bounces

      if bounced?
        Util.log "#{@piece}: Checking for opponents back home which may now fail..."
        @turn.opponents(@piece.area.province, @piece).each do |op|
          op.order.check if op.order.successful?
        end
      end
      check_disruptions
      @checked = true
    end

    def execute(next_turn)
      if dislodged?
        Util.log "#{piece}: Dislodged..."
        next_turn.copy_piece_dislodged(piece, piece.area)
      else
        Util.log "#{piece}: Staying in #{piece.area}..."
        next_turn.copy_piece_to(piece, piece.area)
      end
    end
  end
end

require_relative './move_order'
require_relative './hold_order'
require_relative './support_order'
require_relative './convoy_order'
