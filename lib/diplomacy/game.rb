require_relative './map'
require_relative './turn'
require_relative './player'
require_relative './util'
require_relative './error'
require_relative './director'

module Diplomacy
  class Game
    # --- Class ------------------------------

    # Create a game
    def initialize(name:, map: Map.new)
      @name = name
      @map = map
      @piece_icon_id = @supply_icon_id = @map.id
      @director_mode = false
      @nice_mode = false
      @director = nil
      @turns = []
    end

    # --- Queries ----------------------------

    attr_reader :name, :map, :turns, :director

    def started?
      !@turns.empty?
    end

    def turn
      @turns[-1] || @map.first_turn
    end

    alias current_turn turn

    def previous_turn
      @turns[-2]
    end

    def id(turn = current_turn)
      [name, turn.id].join('-')
    end

    def powers
      turn.powers
    end

    def power(id)
      Util.partial_match(turn.powers, id)
    end

    def power_definitions
      map.power_definitions
    end

    def power_definition(id)
      map.power_definition(id)
    end

    # --- Commands ---------------------------

    attr_accessor :director_mode
    attr_accessor :nice_mode
    attr_writer :name

    def start(bots = true, nice = true)
      self.nice_mode = nice
      first_turn = @map.first_turn.dup
      first_turn.game = self
      @turns.push first_turn
      remove_bots if !bots
      start_director
      request_orders
    end

    def remove_bots
      turn.powers.each do |power|
        if power.definition.player.is_a?(AI)
          power.definition.player = nil
        end
      end
    end

    def start_director
      human_power = turn.powers.find { |p| p.definition.player.is_a?(Human) }
      if director_mode && !human_power.nil?
        @director = Director.new(self, human_power.definition)
      end
    end

    def request_orders
      turn.idle_powers.each do |power|
        power.definition.player&.request_orders(self, power)
      end
    end

    def inspect
      "#{self.class}(#{turn})"
    end

    # Adjudicate all orders and move pieces.
    # Raises an exception if there is a problem.
    def judge
      raise Error, 'Game not started' unless started?
      t = turn.next_turn
      @turns.push t
      Util.log '-------------------------------------'
      Util.log ''
      director&.direct(t)
      request_orders
    end

    def province_captured(province, oldowner, newowner)
      director&.province_captured(province, oldowner, newowner)
    end
  end
end
