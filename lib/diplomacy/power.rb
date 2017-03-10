require_relative './order'
require_relative './rgb'
require_relative './player'

module Diplomacy
  # A Great Power. A power retains its pieces and position even if
  # players come and go.
  class Power
    # --- Class ------------------------------

    # Create a power.
    def initialize(name, adjectives, colours)
      @name, @adjectives = name, adjectives
      @province_colour = RGB.new(colours[0])
      @resource_colour = RGB.new(colours[1])
      @player = DopeyBot.new
      @homes = []
    end

    # --- Queries ----------------------------

    attr_reader :name, :adjectives, :player
    attr_reader :province_colour, :resource_colour
    attr :homes

    # Primary adjective.
    def adjective
      @adjectives.first
    end

    # List of current orders.
    def orders
      @orders
    end

    # Internal representation.
    def inspect
      "#{self.class}:#{to_s}"
    end

    alias :to_s :name

    # --- Commands ---------------------------

    def player=(value)
      @player = value
    end

    # Notify the player of this power that action is now required.
    def request_orders
      @player.request_orders
    end

    # Set this power's controller. Could be a human or an AI.
    # Raise an error if there is already a human player playing
    # this power.
    def set_player(player)
      if @player.class.is_a?(Human)
        raise Error, "Power #{@name} is already being played by a human"
      else
        @player = player
      end
    end

    def add_home(province)
      @homes |= [province]
    end
  end

  # Dummy power representing an uncontrolled area.
  class Uncontrolled < Power
    def initialize(colours)
      super("Uncontrolled", "Uncontrolled", colours)
      @player = nil
    end
  end
end
