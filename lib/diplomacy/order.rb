module Diplomacy
  class Order
    # --- Class ------------------------------

    RESULTS = [
      AMBIGUOUS = 'ambiguous'.freeze,
      BOUNCED = 'bounced'.freeze,
      CONVOY_ATTACKED = 'convoy attacked'.freeze,
      CUT = 'cut'.freeze,
      DISLODGED = 'dislodged'.freeze,
      FAILED = 'failed'.freeze,
      IMPOSSIBLE = 'impossible'.freeze,
    ].freeze

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

    def bounced?
      @results.include?(BOUNCED)
    end

    def cut?
      @results.include?(CUT)
    end

    def dislodged?
      @results.include?(DISLODGED)
    end

    def inspect
      "Order:#{self}"
    end

    def successful?
      @results.empty?
    end

    def to_s
      @string ||= string
      @string + results_string
    end

    def results_string
      if !@results.empty?
        ' (' + @results.join(', ') + ')'
      else
        ''
      end
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
      Util.log "#{self} results changed"
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

    def execute(_next_turn)
      raise 'Abstract'
    end

    def piece_dislodged
      # Do nothing by default
    end

    def validate
      # Do nothing by default
    end
  end
end

require_relative './piece_order'
