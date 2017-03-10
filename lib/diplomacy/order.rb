module Diplomacy
  class Order
    # --- Class ------------------------------

    RESULTS = [
      AMBIGUOUS = "ambiguous",
      BOUNCED = "bounced",
      CONVOY_ATTACKED = "convoy attacked",
      CUT = "cut",
      DISLODGED = "dislodged",
      FAILED = "failed",
      IMPOSSIBLE = "impossible",
    ]

    def initialize(turn)
      @turn = turn
      @checked = false
      @string = nil
      @results = []
    end

    # --- Queries ----------------------------

    attr_reader :turn, :piece, :checked

    def <=>(other)
      to_s <=> other.to_s
    end
    include Comparable

    def bounced?; @results.has(BOUNCED) end
    def cut?; @results.has(CUT) end
    def dislodged?; @results.has(DISLODGED) end

    def inspect
      "Order:#{to_s}"
    end

    def successful?; @results.empty? end

    def to_s
      @string ||= string
      return @string + results_string
    end

    def results_string
      if not @results.empty?
        return " (" + @results.join(', ') + ")"
      end
      return ""
    end

    def text
      raise RuntimeError, "Method 'text' should be defined in #{self.class}"
    end

    def attacking_from
      home # default but diff. for convoyed moves
    end

    # --- Commands ---------------------------

    def add_result(result)
      @results |= [result]
      log "#{self} results changed"
    end

    def tally_strength
      # Do nothing by default
    end

    def check_bounces
      # Do nothing by default
    end

    def check_disruptions
      # Do nothing by default
    end

    def cut_support
      # Do nothing by default
    end

    def execute(next_turn)
      raise "Abstract"
    end

    def piece_dislodged
      # Do nothing by default
    end

    def validate
      # Do nothing by default
    end
  end
end

require_relative './pieceorder'
