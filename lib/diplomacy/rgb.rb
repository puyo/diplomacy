# A colour specified with three bytes for red, green and blue.
class RGB
  # Red.
  attr_reader :r
  # Green
  attr_reader :g
  # Blue
  attr_reader :b

  # Create a colour in one of two ways.
  #   RGB.new("#ffffff") == RGB.new(255, 255, 255)
  def initialize(*args)
    if args.size == 1 && args[0].is_a?(String)
      s = args[0]
      if s[0].chr == '#'
        s = s[1...s.size]
      end
      value = s.hex
      @r = (value >> 16) & 0xff
      @g = (value >> 8) & 0xff
      @b = (value >> 0) & 0xff

    elsif args.size == 3 && args[0].is_a?(Integer) && args[1].is_a?(Integer) && args[2].is_a?(Integer)
      @r, @g, @b = *args
    else
      raise ArgumentError, "Invalid arguments to create a RGB colour: #{value}"
    end
  end

  # The colour as a hex triplet (String) preceeded by a hash symbol
  # ('#').
  def hex
    format('#%02x%02x%02x', @r, @g, @b)
  end

  alias to_s hex

  # Internal representation.
  def inspect
    "#<RGB:#{hex}>"
  end

  def *(other)
    RGB.new([Integer(@r * other), 255].min, [Integer(@g * other), 255].min, [Integer(@b * other), 255].min)
  end

  def +(other)
    RGB.new([Integer(@r + other.r), 255].min, [Integer(@g + other.g), 255].min, [Integer(@b + other.b), 255].min)
  end

  def value
    hex[1..-1].hex
  end

  def <=>(other)
    [@r, @g, @b] <=> [other.r, other.g, other.b]
  end

  include Comparable
end
