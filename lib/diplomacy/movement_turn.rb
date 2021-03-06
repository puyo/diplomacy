require_relative './turn'
require_relative './order'

module Diplomacy
  class MovementTurn < Turn
    # --- Class ------------------------------

    ORDER_TYPES = [
      ConvoyOrder,
      SupportOrder,
      HoldOrder,
      MoveOrder,
      ConvoyedMoveOrder
    ].freeze

    def self.from_string(str, default = Spring)
      {
        'Spring' => Spring,
        'Autumn' => Autumn,
      }.fetch(str, default)
    end

    # --- Queries ----------------------------

    def name
      'Movement'
    end

    def default_order(piece)
      HoldOrder.new(turn: self, piece: piece)
    end

    def orders_template(power_definition)
      power = power(power_definition)
      result = []
      power.pieces.each do |piece|
        result << "#{piece.type.upcase} #{piece.area.location}"
      end
      result.sort.join(" \n") + " \n"
    end

    # --- Commands ---------------------------

    def add_order(order)
      order.piece.order = order
    end

    def remove_order(order)
      order.piece.order = nil
    end

    def next_turn
      orders_fill
      orders_validate
      orders_check_convoys
      orders_cut_supports
      orders_tally_strengths
      orders_check_bounces

      if dislodgements?
        result = RetreatTurn.new(map: @map, previous_turn: self)
        orders_execute(result)
        result.pieces_dislodged.each do |piece|
          occupied = piece.area.connections.reject { |a| result.piece(a.province).nil? }
          piece.retreats -= occupied
        end
      else
        result = next_season.new(map: @map, previous_turn: self)
        orders_execute(result)
        if self.class == Autumn && result.adjustments?
          result = AdjustmentTurn.new(map: @map, previous_turn: self, next_turn: result)
          orders_execute(result)
        end
      end
      result
    end

    def orders_execute(next_turn)
      Util.log "EXECUTING #{self} -> #{next_turn}"
      orders.each { |o| o.execute(next_turn) }
    end

    def dislodgements?
      orders.any?(&:dislodged?)
    end

    def order_validated(order)
      if order.respond_to?(:destination)
        add_contender(order.destination.province, order.piece)
      end
    end

    def orders_check_bounces
      Util.log 'CHECK BOUNCES'
      orders.sort { |a, b| b.piece.strength <=> a.piece.strength }.each do |order|
        if order.successful?
          if !order.checked
            order.check
          else
            Util.log "#{order}: Already checked, skipping..."
          end
        end
      end
    end

    def orders_check_convoys
      Util.log 'CHECK CONVOYS'
      orders.each do |o|
        o.check_disruptions if o.successful?
      end
    end

    def orders_cut_supports
      Util.log 'CUT SUPPORTS'
      orders.each(&:cut_support)
    end

    def orders_tally_strengths
      Util.log 'TALLY STRENGTHS'
      orders.each(&:tally_strength)
    end
  end

  class Spring < MovementTurn
    def season
      'Spring'
    end

    def type_id
      's1'
    end

    def next_season
      Autumn
    end

    def next_year
      @year
    end
  end

  class Autumn < MovementTurn
    def season
      'Autumn'
    end

    def type_id
      's2'
    end

    def next_season
      Spring
    end

    def next_year
      @year + 1
    end
  end
end
