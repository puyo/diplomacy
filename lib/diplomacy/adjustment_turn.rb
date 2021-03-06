require_relative './turn'
require_relative './build_order'
require_relative './waive_order'
require_relative './disband_order'

module Diplomacy
  class AdjustmentTurn < Turn
    # --- Class ------------------------------

    ORDER_TYPES = [BuildOrder, DisbandOrder].freeze

    def initialize(map:, previous_turn:, next_turn:)
      super(map: map, previous_turn: previous_turn)
      @previous_turn = previous_turn
      @next_turn = next_turn
      @adjustments = next_turn.adjustments
      @orders = Hash.new { |h, k| h[k] = [] }
    end

    # --- Queries ----------------------------

    def season
      'Winter'
    end

    def name
      'Adjustment'
    end

    def type_id
      'z'
    end

    def next_year
      @next_turn.year
    end

    def year
      @previous_turn.year
    end

    def orders(power = nil)
      if power
        @orders[power(power).definition]
      else
        @orders.values.flatten
      end
    end

    # --- Commands ---------------------------

    def next_turn
      result = @next_turn
      orders_fill
      orders_validate
      orders_execute(result)
      result
    end

    def orders_execute(next_turn)
      Util.log "EXECUTING #{self} -> #{next_turn}"
      orders.each { |o| o.execute(next_turn) }
    end

    def add_order(order)
      @orders[order.power.definition].push(order)
    end

    def remove_order(order)
      @orders[order.power.definition].delete(order)
    end

    def number_of_builds(power_definition)
      diff = @adjustments[power_definition]
      diff.positive? ? diff : 0
    end

    def number_of_disbands(power_definition)
      diff = @adjustments[power_definition]
      diff.negative? ? -diff : 0
    end

    def orders_fill
      Util.log "FILLING IN DEFAULT ORDERS FOR TURN #{self}"
      @adjustments.each do |power_definition, diff|
        orders = orders(power_definition)
        power = power(power_definition)

        if diff.positive?
          ngained = diff
          ok_orders = orders.find_all do |o|
            o.power.definition == power_definition && (o.is_a?(BuildOrder) || o.is_a?(WaiveOrder))
          end
          missing = ngained - ok_orders.size
          if missing.positive?
            missing.times do
              order = WaiveOrder.new(power: power)
              Util.log "  #{order}"
              add_order(order)
            end
          end
        else
          nlost = -diff
          ok_orders = orders.find_all do |o|
            o.power.definition == power_definition && o.is_a?(DisbandOrder)
          end
          missing = nlost - ok_orders.size
          unordered_pieces = power.pieces - ok_orders.map(&:piece)
          unordered_pieces.compact!
          unordered_pieces.map! do |piece|
            distance = 0
            piece.area.province.breadth_first_search do |prov, dist|
              if power.home?(prov)
                distance = dist
                break
              end
            end
            [distance, piece]
          end
          unordered_pieces.compact!
          unordered_pieces = unordered_pieces.sort_by { |dist, _piece| -dist }
          missing.times do
            dist, piece, _home = unordered_pieces.shift
            order = DisbandOrder.new(turn: self, piece: piece)
            Util.log "  #{order} (distance from home = #{dist})"
            add_order(order)
          end
        end
      end
    end

    def orders_validate
      Util.log "VALIDATING #{self}"
      @powers.each do |power|
        orders(power.definition).each do |order|
          order.validate
          order_validated(order) if order.successful?
          Util.log "  #{order}"
        end
      end
    end

    def orders_template(power_definition)
      result = ''
      number_of_builds(power_definition).times do
        result << "BUILD \n"
      end
      number_of_disbands(power_definition).times do
        result << "DISBAND \n"
      end
      result
    end
  end
end
