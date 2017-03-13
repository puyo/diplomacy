require_relative './move_order'

module Diplomacy
  class ConvoyedMoveOrder < MoveOrder
    # --- Class ------------------------------

    REGEXP = /^([^-]+?)(?:-(.+?))+$/

    def initialize(turn:, piece:, path:, destination:)
      @path = path
      super(turn: turn, piece: piece, destination: destination)
    end

    def self.parse(power, match_data, mine = true)
      parts = match_data[0].split(/-/)
      piece = power.turn.parse_piece(power, parts.shift, mine)
      destination = power.turn.map.parse_area(parts.pop, piece.type)
      path = parts.map { |p| power.turn.map.parse_area(p.strip, 'f') } # hard coding...
      new(turn: power.turn, piece: piece, path: path, destination: destination)
    end

    # --- Queries ----------------------------

    attr_reader :path
    attr_reader :destination

    def string
      "#{@piece} - #{@path.join(' - ')} - #{@destination}"
    end

    def text
      [@piece.id, @path.map(&:location).join(' - '), @destination.location].join(' - ').upcase
    end

    # --- Commands ---------------------------

    def check_bounces
      super
      notify_convoys
    end

    def check_swap_bounce
      # Convoyed pieces don't swap bounce
    end

    def check_disruptions
      @path.each do |area|
        opponents = @turn.opponents(area.province, @piece)
        opponents.delete_if do |o|
          o.order.is_a?(ConvoyOrder) && o.order.piece_convoyed == @piece
        end
        next if opponents.empty?
        Util.log "Convoy #{@piece} attacked by #{opponents.join(', ')}"
        add_result(CONVOY_ATTACKED)
        notify_convoys
        break
      end
    end

    def approaching?(_, _)
      false
    end

    def validate
      last = piece.area
      @path.each do |area|
        if !(convoy = @turn.piece(area))
          Util.log "No convoy available from #{last} to #{area}."
          add_result(FAILED)
        elsif !convoy.order.is_a?(ConvoyOrder)
          Util.log "Convoy '#{convoy}' is not convoying for move '#{self}'. Its order is #{convoy.order.class}"
          add_result(FAILED)
        elsif convoy.order.piece_convoyed != @piece
          Util.log "Convoy '#{convoy}' is not convoying piece for move '#{self}'."
          add_result(FAILED)
        elsif convoy.order.piece_destination != @destination
          Util.log "Convoy '#{convoy}' is not convoying to destination for move '#{self}'."
          add_result(FAILED)
        end
      end
      notify_convoys
    end

    def notify_convoys
      if !@piece.order.successful?
        @piece.supports.clear
        @path.each do |area|
          convoy = @turn.piece(area)
          if !(convoy &&
               convoy.order == ConvoyOrder &&
               convoy.order.piece_convoyed == @piece)
            next
          end
          Util.log "Notifying convoy #{convoy} of #{self} failure"
          convoy.add_result(FAILED)
        end
      end
    end

    def convoy_dislodged(_convoy)
      add_result(FAILED)
      notify_convoys
    end

    def attacking_from
      @path[-1]
    end
  end
end
