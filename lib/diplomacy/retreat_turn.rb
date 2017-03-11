require_relative './turn'
require_relative './retreat_order'
require 'pp'

module Diplomacy
  class RetreatTurn < Turn
    ORDER_TYPES = [RetreatOrder, DisbandOrder]

    def next_turn_type; @prevturn.next_season end
    def season; @prevturn.season end
    def name; "Retreats" end
    def type_id; "#{@prevturn.type_id}r" end
    def next_year; @prevturn.next_year end
    def year; @prevturn.year end

    def initialize(map, prevturn)
      super(map, prevturn)
      @prevturn = prevturn
    end

    def next_turn
      result = next_turn_type.new(@map, self)

      orders_fill
      orders_validate
      orders_check
      orders_execute(result)

      if @prevturn.class == Autumn and result.adjustments?
        result = AdjustmentTurn.new(@map, self, result)
        orders_execute(result)
      end
      return result
    end

    def add_order(order)
      order.piece.order = order
    end

    def remove_order(order)
      order.piece.order = nil
    end

    def orders_check
      @pieces_dislodged.each do |area, piece|
        clashes = @pieces_dislodged.find_all do |a,p|
          p != piece and p.order.is_a?(RetreatOrder) and p.destination == piece.destination
        end
        if !clashes.empty?
          pieces = clashes + [[area, piece]]
          log "Clashing retreats to #{piece.destination}: #{pieces.map{|a,p| p}.join(', ')}"
          pieces.each do |area, piece|
            piece.order.add_result(Order::BOUNCED)
          end
        end
      end
    end

    def orders_execute(next_turn)
      log "EXECUTING #{self} -> #{next_turn}"
      @pieces.each do |area, piece|
        next_turn.copy_piece_to(piece, area)
      end
      @pieces_dislodged.each do |area, piece|
        piece.order.execute(next_turn)
      end
    end

    def orders_fill
      log "FILLING IN DEFAULT ORDERS FOR TURN #{self}"
      @pieces_dislodged.each do |area, piece|
        if piece.order.nil?
          order = default_order(piece)
          log "  #{order}"
          add_order(order)
        end
      end
    end

    def orders_validate
      log "VALIDATING #{self}"
      @pieces_dislodged.each do |area, piece|
        piece.order.validate
        log "  #{piece.order}"
      end
    end

    def orders_template(power_definition)
      result = ""
      power(power_definition).pieces_dislodged.each do |piece|
        if piece.retreats.size > 0
          result << piece.type.upcase << ' ' << piece.area.location
          result << ' - '
          result << piece.retreats.map{|a| a.location }.join(' or ')
          result << "\n"
        else
          result << "DISBAND "
          result << piece.type.upcase << ' ' << piece.area.location
          result << "\n"
        end
      end
      return result
    end

    def default_order(piece)
      DisbandOrder.new(self, piece)
    end
  end
end
