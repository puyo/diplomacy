module Diplomacy
  # Per-turn information about a power.
  class Turn::Power
    # --- Class ------------------------------

    def initialize(turn, definition, provinces=[], pieces=[], pieces_dislodged=[])
      @turn = turn
      @definition, @pieces, @provinces = definition, pieces, provinces
      @pieces_dislodged = pieces_dislodged
      @submitted = false
    end

    # --- Queries ----------------------------

    attr_reader :turn, :definition, :provinces

    def to_s
      "#{definition} on turn #{turn}"
    end

    def pieces
      @pieces
    end

    def pieces_dislodged
      @pieces_dislodged
    end

    def pieces_all
      @pieces + @pieces_dislodged
    end

    def submitted?; @submitted end

    def home?(province)
      @definition.homes.include?(province)
    end

    def owns?(province)
      @provinces.include?(province)
    end

    def orders
      pieces_all.map{|p| p.order }.compact
    end

    def inspect
      result = "#{@definition.name}"
      if pieces.empty?
        result << "\n"
      else
        result << ": " << pieces.join(", ") << "\n"
        orders = turn.orders(self)
        if orders.size > 0
          result << " ORDERS\n"
          result << "  " << orders.join("\n  ") << "\n"
        end
      end
      return result
    end

    def unordered_pieces
      pieces_all.find_all{|p| p.order.nil?}
    end

    def supply_centres
      @provinces.find_all{|p| p.supply? }
    end

    # --- Commands ---------------------------

    def make_piece(location)
      @turn.make_piece(self, location)
    end

    def submitted=(value)
      @submitted = value
    end

    def add_piece(piece)
      @pieces |= [piece]
    end

    def remove_piece(piece)
      Util.log "#{self}: Removing piece #{piece}..."
      @pieces.delete_if{|p| p == piece}
      @pieces_dislodged.delete_if{|p| p == piece}
    end

    def add_piece_dislodged(piece)
      @pieces_dislodged |= [piece]
    end

    def add_province(province)
      @provinces |= [province]
    end

    def remove_province(province)
      @provinces.delete province
    end

    def submit_orders(text)
      @turn.submit_orders(self, text)
    end
  end
end
