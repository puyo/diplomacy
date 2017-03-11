require_relative './area'

module Diplomacy
  # One of the logical named sections of the map. A province.
  class Province
    # --- Class ------------------------------

    # Create a province.
    def initialize(map, id, name, supply, start_owner)
      @map, @id, @name, @supply = map, id, name, supply
      @areas = {}
      @start_owner = start_owner
    end

    # --- Queries ----------------------------

    attr_reader :map

    # Name. e.g. "Liverpool"
    attr_reader :name

    # Unique string ID among provinces. e.g. "lpl"
    attr_reader :id

    # Coordinates of the supply depot for this province, if there is
    # one (otherwise nil).
    attr_reader :supply

    attr_reader :start_owner

    alias to_s name

    def supply?
      !@supply.nil?
    end
    alias supply_centre? supply?
    alias supply_center? supply?

    def inspect
      "Province:<#{self}>"
    end

    # List of all areas in this province.
    def areas(type = nil)
      if type
        if areas = @areas[type]
          areas.values
        else
          []
        end
      else
        @areas.values.map(&:values).flatten
      end
    end

    def area(type, key)
      @areas[type] && @areas[type][key.downcase]
    end

    # The province name and ID.
    def label
      "#{@name} (#{@id})"
    end

    # The coordinates at which to paint a label.
    # (Average of the area coodinates, which is not always best
    # but easier than specifying them in the definition file.)
    def label_coordinates
      @map.types.each do |type|
        areas(type)&.each do |area|
          if area.name == ''
            return area.coordinates[0]
          end
        end
      end
    end

    # The set of coordinates at which to floodfill this province if
    # it is owned by a power.
    def paint_coordinates
      result = []
      areas.each do |a|
        # TODO: This is a hack so that only land is painted.
        # Fix this up with a mapping in from type => col the
        # XML file.
        result |= a.coordinates if a.type == 'a'
      end
      result
    end

    # The coordinates at which to place the piece on this area if
    # there is a piece on this area.
    def piece_coordinates(turn)
      areas.each do |a|
        if turn.piece(a)
          result = a.coordinates[0]
          return result
        end
      end
      nil
    end

    # A map of area IDs to areas (without duplicating areas which
    # have the same ID but different types).
    def unique_areas
      result = {}
      @map.types.reverse.each do |t|
        @areas[t].each do |area|
          result[area.id.downcase] = area
        end
      end
      result.values
    end

    def adjacent_provinces
      areas.map { |a| a.connections.map(&:province) }.flatten.uniq
    end

    # --- Commands ---------------------------

    # Add a new area to this province.
    def add_area(area)
      @areas[area.type] = {} unless @areas[area.type]
      @areas[area.type][area.key] = area
    end

    def breadth_first_search
      queue, visited, distance = [self], [], 0
      until queue.empty?
        newqueue = []
        queue.each do |province|
          yield province, distance
          newconnections = province.adjacent_provinces - visited
          newqueue |= newconnections
          visited |= newconnections
        end
        queue.replace(newqueue)
        distance += 1
      end
    end
  end
end
