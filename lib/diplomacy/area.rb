module Diplomacy
  # Each map province contains several abstract "areas" which define what pieces
  # can move through that province (piece type and area type must match), where
  # such a piece will be placed and the areas connected to it. An example of an
  # area is St. Petersburg's North Coast ("fstpnc"), which is a fleet ("f") type
  # area in St. Petersburg ("stp") with the ID "nc" to distinguish it from the
  # South Coast. It is connected to different areas than St. Petersburg's South
  # Coast ("fstpsc").
  #
  class Area
    # --- Class ------------------------------

    # Create a new area.
    def initialize(type, id, name, province, connections, coordinates)
      @type, @id, @name, @province, @connections, @coordinates = type, id, name, province, connections, coordinates
    end

    # --- Queries ----------------------------

    attr_reader :id

    # The piece type that can travel here.
    attr_reader :type

    # The province to which this area belongs.
    attr_reader :province

    # The areas connected to this area.
    attr_reader :connections

    # Name. e.g. "North Coast"
    attr_reader :name

    # The coordinates for placing a piece or floodfilling.
    attr_reader :coordinates

    def key
      @id
    end

    def location
      idstr = @id == '' ? '' : "/#{@id}"
      "#{@province.id}#{idstr}"
    end

    # This area's name, prefixed by its province's name.
    def label
      namestr = @name == '' ? '' : ", #{@name}"
      "#{@province.name}#{namestr}"
    end
    alias to_s label

    def inspect
      "Area:<#{type.upcase} #{label}>"
    end

    def self_and_connections
      [self] + @connections
    end

    def <=>(other)
      to_s <=> other.to_s
    end
    include Comparable

    # --- Commnads ---------------------------

    # Distance until block returns true
    def distance(queue = [self], visited = [], distance = 0)
      until queue.empty?
        newqueue = []
        queue.each do |area|
          if yield area, distance
            return distance
          end
          newconnections = area.connections - visited
          newqueue |= newconnections
          visited |= newconnections
        end
        queue.replace(newqueue)
        distance += 1
      end
    end

    def breadth_first_search
      queue, visited, distance = [self], [], 0
      until queue.empty?
        newqueue = []
        queue.each do |area|
          yield area, distance
          newconnections = area.connections - visited
          newqueue |= newconnections
          visited |= newconnections
        end
        queue.replace(newqueue)
        distance += 1
      end
    end
  end
end
