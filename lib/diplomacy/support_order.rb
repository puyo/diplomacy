require_relative './piece_order'

module Diplomacy
  class SupportOrder < PieceOrder
    # --- Class ------------------------------

    REGEXP = /^(.*) (?:s|support) (.*)/

    def initialize(turn, piece, supported_piece)
      super(turn, piece)
      @supported_piece = supported_piece
    end

    def self.parse(power, match_data, mine)
      piece = power.turn.parse_piece(power, match_data[1], mine)
      # order = power.turn.parse_order(power, match_data[2], false)
      supported_piece = power.turn.parse_piece(power, match_data[2], false)
      SupportOrder.new(power.turn, piece, supported_piece)
    end

    # --- Queries ----------------------------

    attr_reader :supported_piece

    def attacking_self?
      supported_piece.moving? &&
        supported_piece.order.target &&
        supported_piece.order.target.owner == piece.owner &&
        !supported_piece.order.target.moving?
    end

    def support_self?
      supported_piece == piece
    end

    def support_move?
      supported_piece.order.respond_to?(:destination)
    end

    def support_attack_on_self?
      (target = supported_piece.destination.piece) && target.owner == piece.owner
    end

    def unreachable?
      provinces = piece.area.connections.map(&:province)
      dest = supported_piece.destination.province
      !provinces.include?(dest)
    end

    def piece?
      !supported_piece.nil?
    end

    def orders_match?
      # supported.piece.order == supported
      true
    end

    def string
      "#{piece} SUPPORT #{supported_piece}"
    end

    def text
      "#{piece.id.upcase} SUPPORT #{supported_piece.id.upcase}"
    end

    # --- Commands ---------------------------

    def tally_strength
      if successful?
        Util.log "#{piece} added strength to #{supported_piece}..."
        supported_piece.add_support(piece)
      end
    end

    def piece_dislodged
      Util.log "#{piece}: Withdrawing support for '#{supported_piece}' due to dislodgement"
      supported_piece.remove_support(piece)
      supported_piece.order.check
    end

    def validate
      if support_self?
        add_result(IMPOSSIBLE)
        Util.log "Attempt by piece to support itself, with order '#{self}'"
      end
      if !piece?
        add_result(IMPOSSIBLE)
        Util.log "Attempt to support non-existant piece, with order '#{self}'"
      end
      if !orders_match?
        add_result(IMPOSSIBLE)
        Util.log "Supported piece's order does not match support order '#{self}'"
      end
      if unreachable?
        add_result(IMPOSSIBLE)
        Util.log "Supporting piece cannot reach destination in support order '#{self}'"
      end
      if attacking_self?
        add_result(IMPOSSIBLE)
        Util.log "Supporting piece cannot support attack on friendly unit in support order '#{self}'"
      end
    end
  end
end
