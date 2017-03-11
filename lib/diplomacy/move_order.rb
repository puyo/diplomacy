require_relative './piece_order'

module Diplomacy
  class MoveOrder < PieceOrder
    # --- Class ------------------------------

    REGEXP = /^([^-]+)-([^-]+)$/

    def initialize(turn, piece, destination)
      super(turn, piece)
      @destination = destination
    end

    def self.parse(power, match_data, mine)
      piece = power.turn.parse_piece(power, match_data[1], mine)
      destination = power.turn.map.parse_area(match_data[2], piece.type)
      MoveOrder.new(power.turn, piece, destination)
    end

    # --- Queries ----------------------------

    attr :destination

    def home; @piece.area.province end

    def attacking_self?
      target and target.owner == @piece.owner and not target.moving?
    end

    def string
      "#{piece} - #{destination}"
    end

    def text
      "#{piece.id.upcase} - #{destination.location.upcase}"
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
      log "#{@piece}: Checking for swap bounces..."
      if target and target.moving? and
        target.destination.province == @piece.area.province and
        target.strength >= @piece.strength
      then
        log "#{@piece} (#{@piece.strength}) swap-bounced off #{target} (#{target.strength})"
        @piece.bounce
      end
    end

    def check_weak_bounce
      log "#{@piece}: Checking for weak bounces..."
      opponents = @turn.opponents(destination.province, @piece)
      if opponents.size > 0
        summary = opponents.map{|a| "#{a} (#{a.strength})"}.join(', ')
        log "#{@piece} (#{@piece.strength}) bounced off #{summary} in #{destination}"
        @piece.bounce
      elsif attacking_self?
        log "#{@piece} (#{@piece.strength}) bounced off friendly piece"
        @piece.bounce
      elsif target
        dislodge_piece(target, [@piece] + @piece.supports)
      end
    end

    def dislodge_piece(target, attackers)
      fail if attackers.size != @piece.strength
      log "#{attackers.join(', ')} (#{attackers.size}) PUSH #{target} (#{target.strength})"
      attacked_from = attackers.map{|a| a.area.province }
      if approaching?(target, @piece)
        @turn.remove_contender(@piece.area.province, target)
        target.dislodge(attacked_from)
      elsif not target.moving?
        target.dislodge(attacked_from)
      end
    end

    def approaching?(a, b)
      a.approaching?(b)
    end

    def piece_dislodged
      if @piece.area
        log "#{@piece}: Checking for opponents back home which may now succeed..."
        opponents = @turn.opponents(@piece.area.province, @piece)
        opponents.each do |op|
          log "#{@piece}: Rechecking #{op}..."
          if op.order and not op.order.successful?
            op.order.check 
          end
        end
      end
    end
    
    def cut_support
      log "#{piece} cutting supports..."
      if successful? and
        target and
        target.order.kind_of?(SupportOrder) and
        target.owner != @piece.owner and
        target.order.supported_piece.destination.province != attacking_from
      then
        log "Support from #{target} cut by #{@piece}"
        target.order.add_result(CUT)
        target.order.supported_piece.remove_support(target)
      end
    end

    def execute(next_turn)
      if successful?
        log "#{piece}: Moving to #{destination}..."
        next_turn.copy_piece_to(piece, destination)
      elsif dislodged?
        log "#{piece}: Dislodged..."
        next_turn.copy_piece_dislodged(piece, piece.area)
      else
        log "#{piece}: Staying put..."
        next_turn.copy_piece_to(piece, piece.area)
      end
    end

    def unreachable?
      not @piece.area.connections.include?(@destination)
    end

    def validate
      if unreachable?
        log "Piece #{@piece} cannot move to #{@destination} because that is impossible"
        add_result(IMPOSSIBLE)
      end
      if attacking_self?
        add_result(IMPOSSIBLE)
        log "Cannot attack own unit with order '#{self}'"
      end
    end
  end
end

require_relative './convoyed_move_order'
