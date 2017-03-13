require_relative './piece_order'

module Diplomacy
  class MoveOrder < PieceOrder
    # --- Class ------------------------------

    REGEXP = /^([^-]+)-([^-]+)$/

    def initialize(turn:, piece:, destination:)
      super(turn: turn, piece: piece)
      @destination = destination
    end

    def self.parse(power, match_data, mine)
      piece = power.turn.parse_piece(power, match_data[1], mine)
      destination = power.turn.map.parse_area(match_data[2], piece.type)
      new(turn: power.turn, piece: piece, destination: destination)
    end

    # --- Queries ----------------------------

    attr_reader :destination

    def home
      @piece.area.province
    end

    def attacking_self?
      target && target.owner == @piece.owner && !target.moving?
    end

    def string
      [piece, destination].join(' - ')
    end

    def text
      [piece.id, destination.location].join(' - ').upcase
    end

    def target
      @turn.piece(@destination.province)
    end

    # --- Commands ---------------------------

    def check_bounces
      check_swap_bounce if successful?
      check_weak_bounce if successful?
    end

    def check_swap_bounce
      Util.log "#{@piece}: Checking for swap bounces..."
      if target && target.moving? &&
         target.destination.province == @piece.area.province &&
         target.strength >= @piece.strength
        Util.log "#{@piece} (#{@piece.strength}) swap-bounced off #{target} (#{target.strength})"
        @piece.bounce
      end
    end

    def check_weak_bounce
      Util.log "#{@piece}: Checking for weak bounces..."
      opponents = @turn.opponents(destination.province, @piece)
      if !opponents.empty?
        summary = opponents.map { |a| "#{a} (#{a.strength})" }.join(', ')
        Util.log "#{@piece} (#{@piece.strength}) bounced off #{summary} in #{destination}"
        @piece.bounce
      elsif attacking_self?
        Util.log "#{@piece} (#{@piece.strength}) bounced off friendly piece"
        @piece.bounce
      elsif target
        dislodge_piece(target, [@piece] + @piece.supports)
      end
    end

    def dislodge_piece(target, attackers)
      raise if attackers.size != @piece.strength
      Util.log "#{attackers.join(', ')} (#{attackers.size}) PUSH #{target} (#{target.strength})"
      attacked_from = attackers.map { |a| a.area.province }
      if approaching?(target, @piece)
        @turn.remove_contender(@piece.area.province, target)
        target.dislodge(attacked_from)
      elsif !target.moving?
        target.dislodge(attacked_from)
      end
    end

    def approaching?(a, b)
      a.approaching?(b)
    end

    def piece_dislodged
      if @piece.area
        Util.log "#{@piece}: Checking for opponents back home which may now succeed..."
        opponents = @turn.opponents(@piece.area.province, @piece)
        opponents.each do |op|
          Util.log "#{@piece}: Rechecking #{op}..."
          if op.order && !op.order.successful?
            op.order.check
          end
        end
      end
    end

    def cut_support
      Util.log "#{piece} cutting supports..."
      if successful? &&
         target &&
         target.order.is_a?(SupportOrder) &&
         target.owner != @piece.owner &&
         target.order.supported_piece.destination.province != attacking_from
        Util.log "Support from #{target} cut by #{@piece}"
        target.order.add_result(CUT)
        target.order.supported_piece.remove_support(target)
      end
    end

    def execute(next_turn)
      if successful?
        Util.log "#{piece}: Moving to #{destination}..."
        next_turn.copy_piece_to(piece, destination)
      elsif dislodged?
        Util.log "#{piece}: Dislodged..."
        next_turn.copy_piece_dislodged(piece, piece.area)
      else
        Util.log "#{piece}: Staying put..."
        next_turn.copy_piece_to(piece, piece.area)
      end
    end

    def unreachable?
      !@piece.area.connections.include?(@destination)
    end

    def validate
      if unreachable?
        Util.log "Piece #{@piece} cannot move to #{@destination} because that is impossible"
        add_result(IMPOSSIBLE)
      end
      if attacking_self?
        add_result(IMPOSSIBLE)
        Util.log "Cannot attack own unit with order '#{self}'"
      end
    end
  end
end

require_relative './convoyed_move_order'
