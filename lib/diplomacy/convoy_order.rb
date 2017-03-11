require_relative './piece_order'

module Diplomacy
  class ConvoyOrder < PieceOrder
    # --- Class ------------------------------

    REGEXP = /^(.*) (?:c|convoy) (.*?)-(.*)$/

    def initialize(turn, piece, piece_convoyed, piece_destination)
      super(turn, piece)
      @piece_convoyed, @piece_destination = piece_convoyed, piece_destination
      @piece_convoyed.convoys << piece
    end

    def self.parse(power, match_data, mine=true)
      piece = power.turn.parse_piece(power, match_data[1], mine)
      piece_convoyed = power.turn.parse_piece(power, match_data[2], false)
      piece_destination = power.turn.map.parse_area(match_data[3], piece_convoyed.type)
      return ConvoyOrder.new(power.turn, piece, piece_convoyed, piece_destination)
    end

    # --- Queries ----------------------------

    attr_reader :piece_convoyed, :piece_destination

    def string
      "#{@piece} CONVOY #{@piece_convoyed.area} - #{@piece_destination}"
    end

    def text
      "#{@piece.id.upcase} CONVOY #{@piece_convoyed.id.upcase} - #{@piece_destination.location.upcase}"
    end

    def piece_dislodged
      @piece_convoyed.order.convoy_dislodged(@piece)
    end

    # --- Commands ---------------------------

    def validate
      if not @piece_convoyed
        puts "Invalid convoy order '#{text}'. No piece to convoy."
        add_result(FAILED)
      end
    end
  end
end
