require_relative './order'

module Diplomacy
  class WaiveOrder < Order
    # --- Class ------------------------------

    REGEXP = /^(?:w|waive)$/

    def initialize(power:)
      super(turn: power.turn)
      @power = power
    end

    def self.parse(power, _match_data, _mine = true)
      new(power)
    end

    # --- Queries ----------------------------

    attr_reader :power

    def string
      "#{power.definition.name} WAIVE"
    end

    def text
      'WAIVE'
    end

    # --- Commands ---------------------------

    def validate
      # Nothing to do
    end

    def execute(next_turn)
      # Also nothing to do
    end
  end
end
