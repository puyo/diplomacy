# A colour specified with three bytes for red, green and blue.
class RGB
  # Red.
  attr :r
  # Green
  attr :g
  # Blue
  attr :b

  # Create a colour in one of two ways.
  #   RGB.new("#ffffff") == RGB.new(255, 255, 255)
  def initialize(*args)
    if args.size == 1 and args[0].is_a? String
      s = args[0]
      if s[0].chr == "#"
        s = s[1...s.size]
      end
      value = s.hex
      @r = (value >> 16) & 0xff
      @g = (value >> 8) & 0xff
      @b = (value >> 0) & 0xff

    elsif args.size == 3 and args[0].is_a? Integer and args[1].is_a? Integer and args[2].is_a? Integer
      @r, @g, @b = *args
    else
      raise ArgumentError, "Invalid arguments to create a RGB colour: #{value}"
    end
  end

  # The colour as a hex triplet (String) preceeded by a hash symbol
  # ('#').
  def hex
    format("#%02x%02x%02x", @r, @g, @b)
  end

  # Internal representation.
  def inspect
    "#<RGB:#{hex}>"
  end

  def *(value)
    RGB.new([Integer(@r*value), 255].min, [Integer(@g*value), 255].min, [Integer(@b*value), 255].min)
  end

  def +(colour)
    RGB.new([Integer(@r + colour.r), 255].min, [Integer(@g + colour.g), 255].min, [Integer(@b + colour.b), 255].min)
  end

  def value
    self.hex[1..-1].hex
  end

  # Comparison operator.
  def <=>(other)
    [@r, @g, @b] <=> [other.r, other.g, other.b]
  end

  include Comparable

  alias :to_s :hex
end
