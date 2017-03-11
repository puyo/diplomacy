require_relative './turn'
require_relative './order'

module Diplomacy
  class MovementTurn < Turn
    # --- Class ------------------------------

    ORDER_TYPES = [ConvoyOrder, SupportOrder, HoldOrder, MoveOrder, ConvoyedMoveOrder]

    def initialize(map, prevturn=nil)
      super(map, prevturn)
    end

    # --- Queries ----------------------------

    def name; "Movement" end

    def default_order(piece)
      HoldOrder.new(self, piece)
    end

    def orders_template(power_definition)
      power = power(power_definition)
      result = []
      power.pieces.each do |piece|
        result << "#{piece.type.upcase} #{piece.area.location}"
      end
      return result.sort.join(" \n")+" \n"
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

      # I'm sure there's a better way to do this...
      if dislodgements?
        result = RetreatTurn.new(@map, self)
        orders_execute(result)
        result.pieces_dislodged.each do |piece|
          occupied = piece.area.connections.reject{|a| result.piece(a.province).nil? }
          piece.retreats -= occupied
        end
      else
        result = next_season.new(@map, self)
        orders_execute(result)

        if self.class == Autumn and result.adjustments?
          result = AdjustmentTurn.new(@map, self, result)
          orders_execute(result)
        end
      end

      return result
    end

    def orders_execute(next_turn)
      log "EXECUTING #{self} -> #{next_turn}"
      orders.each{|o| o.execute(next_turn) }
    end

    def dislodgements?
      !orders.find{|o| o.dislodged?}.nil?
    end

    def order_validated(order)
      if order.respond_to?(:destination)
        add_contender(order.destination.province, order.piece)
      end
    end

    def orders_check_bounces
      log "CHECK BOUNCES"
      orders.sort{|a,b| b.piece.strength <=> a.piece.strength }.each do |order|
        if order.successful?
          if not order.checked
            order.check
          else
            log "#{order}: Already checked, skipping..."
          end
        end
      end
    end

    def orders_check_convoys
      log "CHECK CONVOYS"
      orders.each do |o| 
        o.check_disruptions if o.successful?
      end
    end

    def orders_cut_supports
      log "CUT SUPPORTS"
      orders.each{|o| o.cut_support }
    end

    def orders_tally_strengths
      log "TALLY STRENGTHS"
      orders.each{|o| o.tally_strength }
    end
  end

  class Spring < MovementTurn
    def season; "Spring" end
    def type_id; "s1" end
    def next_season; Autumn end
    def next_year; @year end

    def initialize(map, prevturn=nil)
      super(map, prevturn)
    end
  end

  class Autumn < MovementTurn
    def season; "Autumn" end
    def type_id; "s2" end
    def next_season; Spring end
    def next_year; @year + 1 end

    def initialize(map, prevturn=nil)
      super(map, prevturn)
    end
  end

  TURN_TYPES = {
    'Spring' => Spring,
    'Autumn' => Autumn,
  }
end
