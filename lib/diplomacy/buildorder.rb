require_relative './order'

module Diplomacy
  class BuildOrder < Order
    # --- Class ------------------------------

    REGEXP = /^(?:b|build) (.*)$/

    def initialize(power, area)
      super(power.turn)
      @power, @area = power, area
    end

    def self.parse(power, match_data, mine=true)
      area = power.turn.map.parse_area(match_data[1])
      BuildOrder.new(power, area)
    end

    # --- Queries ----------------------------

    attr_reader :power, :area

    def string
      text
    end

    def text
      "BUILD #{area.type.upcase} #{area.location.upcase}"
    end

    # --- Commands ---------------------------

    def validate
      unless power.owns?(@area.province)
        add_result(Order::IMPOSSIBLE)
        log "#{self} is impossible, #{power} does not own that province"
      end
      unless power.home?(@area.province)
        add_result(Order::IMPOSSIBLE)
        log "#{self} is impossible, #{area.province} is not a home centre of #{power}"
      end
      unless 1 == power.turn.orders(power).find_all{|o| o.is_a?(BuildOrder) and o.area.province == @area.province and o.successful? }.size
        add_result(Order::IMPOSSIBLE)
        log "#{self} is impossible, #{area.province} is already being built upon"
      end
    end

    def execute(next_turn)
      if successful?
        next_turn.build_piece(next_turn.power(@power.definition), @area)
      end
    end
  end
end
