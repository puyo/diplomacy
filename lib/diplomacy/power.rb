require_relative './order'
require_relative './rgb'
require_relative './player'

module Diplomacy
  # A Great Power. A power retains its pieces and position even if
  # players come and go.
  class Power
    # --- Class ------------------------------

    # Create a power.
    def initialize(name:, adjectives:, colours:)
      @name, @adjectives = name, adjectives
      @province_colour = RGB.new(colours[0])
      @resource_colour = RGB.new(colours[1])
      @player = DopeyBot.new
      @homes = []
    end

    # --- Queries ----------------------------

    attr_reader :name, :adjectives, :player
    attr_reader :province_colour, :resource_colour
    attr_reader :homes

    # Primary adjective, in the case of multiple possible adjectives such as
    # "English" and "British".
    def adjective
      @adjectives.first
    end

    # List of current orders.
    attr_reader :orders

    # Internal representation.
    def inspect
      "#{self.class}:#{self}"
    end

    alias to_s name

    # --- Commands ---------------------------

    attr_writer :player

    # Notify the player of this power that action is now required.
    def request_orders
      @player.request_orders
    end

    def add_home(province)
      @homes |= [province]
    end
  end

  # Dummy power representing an uncontrolled area.
  class Uncontrolled < Power
    def initialize(colours)
      super(name: 'Uncontrolled', adjectives: ['Uncontrolled'], colours: colours)
      @player = nil
    end
  end
end
