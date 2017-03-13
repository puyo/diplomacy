require_relative './turn'
require_relative './retreat_order'
require 'pp'

module Diplomacy
  class RetreatTurn < Turn
    # --- Class ------------------------------

    ORDER_TYPES = [RetreatOrder, DisbandOrder].freeze

    def initialize(map:, previous_turn:)
      super(map: map, previous_turn: previous_turn)
      @previous_turn = previous_turn
    end

    # --- Queries ----------------------------

    def next_turn_type
      @previous_turn.next_season
    end

    def season
      @previous_turn.season
    end

    def name
      'Retreats'
    end

    def type_id
      "#{@previous_turn.type_id}r"
    end

    def next_year
      @previous_turn.next_year
    end

    def year
      @previous_turn.year
    end

    # --- Commands ---------------------------

    def next_turn
      result = next_turn_type.new(map: @map, previous_turn: self)
      orders_fill
      orders_validate
      orders_check
      orders_execute(result)
      if @previous_turn.class == Autumn && result.adjustments?
        result = AdjustmentTurn.new(map: @map, previous_turn: self, next_turn: result)
        orders_execute(result)
      end
      result
    end

    def add_order(order)
      order.piece.order = order
    end

    def remove_order(order)
      order.piece.order = nil
    end

    def orders_check
      @pieces_dislodged.each do |area, piece|
        clashes = @pieces_dislodged.find_all do |_a, p|
          p != piece && p.order.is_a?(RetreatOrder) && p.destination == piece.destination
        end
        next if clashes.empty?
        pieces = clashes + [[area, piece]]
        Util.log "Clashing retreats to #{piece.destination}: #{pieces.map { |_a, p| p }.join(', ')}"
        pieces.each do |_area, _piece|
          piece.order.add_result(Order::BOUNCED)
        end
      end
    end

    def orders_execute(next_turn)
      Util.log "EXECUTING #{self} -> #{next_turn}"
      @pieces.each do |area, piece|
        next_turn.copy_piece_to(piece, area)
      end
      @pieces_dislodged.each do |_area, piece|
        piece.order.execute(next_turn)
      end
    end

    def orders_fill
      Util.log "FILLING IN DEFAULT ORDERS FOR TURN #{self}"
      @pieces_dislodged.each do |_area, piece|
        next if !piece.order.nil?
        order = default_order(piece)
        Util.log "  #{order}"
        add_order(order)
      end
    end

    def orders_validate
      Util.log "VALIDATING #{self}"
      @pieces_dislodged.each do |_area, piece|
        piece.order.validate
        Util.log "  #{piece.order}"
      end
    end

    def orders_template(power_definition)
      result = ''
      power(power_definition).pieces_dislodged.each do |piece|
        if !piece.retreats.empty?
          result << piece.type.upcase << ' ' << piece.area.location
          result << ' - '
          result << piece.retreats.map(&:location).join(' or ')
        else
          result << 'DISBAND '
          result << piece.type.upcase << ' ' << piece.area.location
        end
        result << "\n"
      end
      result
    end

    def default_order(piece)
      DisbandOrder.new(turn: self, piece: piece)
    end
  end
end
