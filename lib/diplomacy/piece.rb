require 'pp'
require_relative './turn'

module Diplomacy
  # An army, fleet or other such game piece, owned by a power.
  class Turn
    class Piece
      # --- Class ------------------------------

      class ID
        def <=>(other)
          object_id <=> other.object_id
        end
        include Comparable
      end

      def initialize(turn, type, owner, area, identifier = ID.new)
        @turn = turn
        @type, @owner, @area = type, owner, area
        @supports = []
        @convoys = []
        @order = nil
        raise if !owner.is_a?(Turn::Power)
        raise if !area.is_a?(Area)
        @identifier = identifier
        @retreats = []
      end

      # --- Queries ----------------------------

      attr_reader :type, :owner, :area, :identifier, :order

      # The list of convoys contributing to the conveyance of this
      # piece (assuming it is an army). Used during adjudication.
      attr_accessor :convoys

      # The list of other pieces supporting this piece. Used during
      # adjudication.
      attr_accessor :supports

      # Areas to which this piece may retreat.
      attr_accessor :retreats

      def id
        "#{type} #{area.location}"
      end

      # The combined strength of this piece (e.g. when moving or
      # holding). Defaults to 1 but may be increased by adding
      # supports.
      def strength
        1 + @supports.size
      end

      def bounced?
        @order.bounced?
      end

      def cut?
        @order.cut?
      end

      def dislodged?
        @order.dislodged?
      end

      def <=>(other)
        return 1 if other.nil?
        @identifier <=> other.identifier
      end
      include Comparable

      # String representation.
      def to_s
        result = @type.upcase
        result << ' ' << @area.location if @area
        result
      end

      def inspect
        "Piece:(#{@type.upcase} #{@area})"
      end

      def moving?
        @order.is_a?(MoveOrder) && @order.successful?
      end

      def approaching?(piece)
        moving? && @order.destination.province == piece.area.province
      end

      def destination
        if @order.respond_to?(:destination)
          @order.destination
        else
          @area
        end
      end

      # --- Commands ---------------------------

      def add_support(piece)
        @supports |= [piece]
        Util.log "#{self} supports = #{@supports.join(', ')}"
      end

      def remove_support(piece)
        @supports -= [piece]
        Util.log "#{self} supports = #{@supports.join(', ')}"
      end

      def order=(value)
        if @order && @order == value
          puts "Duplicate order given to the piece #{self}: '#{@order.text}'"
        elsif @order && value
          puts "Two orders given to the piece #{self}: '#{@order.text}' and '#{value.text}'"
          order.add_result(Order::AMBIGUOUS)
        else
          @previous_order = @order
          @order = value
        end
      end

      def dislodge(provinces_attacked_from)
        Util.log "#{self}: Dislodged by attack from #{provinces_attacked_from.join(', ')}"
        no_retreat_provinces = provinces_attacked_from
        if @order.respond_to?(:destination)
          no_retreat_provinces.push @order.destination.province
        end
        @retreats = @area.connections.reject do |area|
          no_retreat_provinces.include? area.province
        end
        Util.log "#{self}: Retreats = #{retreats.join(', ')}"
        order.add_result(Order::DISLODGED)
        order.piece_dislodged
      end

      def bounce
        order.add_result(Order::BOUNCED)
      end

      def nationality
        @owner.definition
      end
    end
  end
end
