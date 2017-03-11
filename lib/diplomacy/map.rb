require 'rexml/document'

require_relative './power'
require_relative './piece'
require_relative './province'
require_relative './error'
require_relative './turnpower'
require_relative './turn'

module Diplomacy

  # A map (such as the standard Diplomacy map of Europe).
  class Map
    # --- Class ------------------------------

    # Load a map with the specified name. This will load the file
    # specified by configuration_path from the maps directory and
    # its associated files, or if it is already loaded, simply
    # return it (maps are cached because they often take some time
    # to load).
    def initialize(id="standard", resource_path=nil)
      @id = id
      @resource_path = resource_path || File.join(__dir__, "..", "..", "resources")

      log "Loading map from #{configuration_path}..."
      doc = nil
      begin
        File.open(configuration_path) do |f|
          doc = REXML::Document.new(f)
        end
      rescue REXML::ParseException => e
        f.close
        raise MapError, "#{e.line}: #{e.message}"
      end

      @power_definitions = []
      @provinces = {}
      @first_turn = nil

      @types = doc.elements["/map"].attribute("types").to_s.split(/,/)
      start = doc.elements["/map/start"]
      @first_year = start.attribute("year", "1901").to_s.to_i
      @first_season = Diplomacy::MovementTurn.from_string(start.attribute('season').to_s, Spring)

      @first_turn = @first_season.new(self)

      doc.elements.each("/map/power") do |e|
        name = e.attribute("name").to_s
        adjectives = e.attribute("adjectives").to_s.split(/,/)
        colours = e.attribute("colours").to_s.split(/,/)
        power_def = Power.new(name, adjectives, colours)
        @power_definitions << power_def

        turn_power = Turn::Power.new(@first_turn, power_def)
        @first_turn.add_power turn_power

        e.elements.each("province") do |e|
          input_province(turn_power, e)
          # $stderr.print name[0].chr.upcase; $stdout.flush
        end
      end

      uncontrolled_e = doc.elements["/map/uncontrolled"]
      colours = uncontrolled_e.attribute("colours").to_s.split(/,/)
      @uncontrolled = Uncontrolled.new(colours)
      @power_definitions << @uncontrolled
      @uncontrolled_start = Turn::Power.new(@first_turn, @uncontrolled)
      @first_turn.add_power @uncontrolled_start
      uncontrolled_e.elements.each("province") do |e|
        input_province(@uncontrolled_start, e)
        # $stderr.print 'U'; $stdout.flush
      end
      # $stderr.puts

      # $stderr.puts "Expanding..."
      expand_links

      # $stderr.puts "Validating..."
      validate

      # $stderr.puts "Loaded #{@provinces.values.size} provinces, #{areas.size} areas."
    end

    # --- Queries ----------------------------

    attr_reader :first_turn, :first_season, :first_year
    attr :uncontrolled

    def power_definitions
      @power_definitions - [@uncontrolled]
    end

    # The string ID of the map as specified when loading (e.g.
    # "standard").
    attr :id

    # Army/terrain types. Should be 1 character strings. e.g. "a"
    # and "f" for army and fleet respectively.
    attr :types

    def province(key)
      @provinces[key]
    end

    def parse_province(text, area_type=nil, area_text=nil)
      text = text.downcase # case unimportant
      parts = text.split(/ /)
      if types.include?(parts[0])
        type = parts.shift
      end
      rest = parts.join(' ').strip
      if result = @provinces[rest[0,3]]
        rest[0,3] = ''
      elsif result = provinces.partial_match(rest){|p| p.name.downcase }
        rest[0,result.name.size] = ''
      else
        raise Error, "Unable to determine province from '#{text}'"
      end
      if area_type.is_a?(String) and not type.nil?
        area_type.replace(type)
      end
      if area_text.is_a?(String)
        area_text.replace(rest)
      end
      return result
    end

    # Some valid locations:
    # StP(sc)
    # StP/sc
    # StPsc
    # StP.sc
    # St. Petersburg South Coast
    # St. Petersburg sc
    # F Lon
    # A Lon

    # Some invalid locations:
    # Lon
    def parse_area(text, type=nil)
      province = parse_province(text, area_type='', area_text='')
      if type.to_s == ''
        type = area_type
      end
      if (areas = province.areas(type)).size == 1
        return areas.first
      elsif area_text != ''
        area_text = area_text.strip.gsub(/[^a-z ]/, '')
        if area = province.areas.partial_match(area_text){|a| a.key }
          return area
        elsif area_text != '' and area = province.areas.partial_match(area_text){|a| a.name }
          return area
        end
      end
      raise Error, "Could not identify area of '#{province}' given '#{area_text}'"
    end

    # A list of all areas.
    def areas
      @provinces.values.map{|r| r.areas }.flatten
    end

    # Internal representation
    def inspect
      "Map:<#{@provinces.inspect}>"
    end

    def power_definition(id)
      @power_definitions.partial_match(id){|pdef| pdef.name.downcase }
    end

    # A list of all provinces.
    def provinces
      @provinces.values
    end

    # All pieces on the board.
    def pieces
      @provinces.values.map{|province| province.pieces}.flatten.compact
    end

    # The directory containing the map definitions.
    def maps_path() File.join(@resource_path, "maps") end

    # The path containing the game supply icons.
    def supply_icons_path() File.join(@resource_path, "supplies") end

    # The path containing the game piece icons.
    def piece_icons_path() File.join(@resource_path, "pieces") end

    # The file from which to read the map settings and information.
    def configuration_path() File.join(maps_path, "#{@id}.xml") end

    # Path to the base map, which is flood-filled and painted on
    # to produce game state maps.
    def base_path() File.join(maps_path, "#{@id}.png") end


    # --- Commands ---------------------------

    def clear
      provinces.each do |province|
        province.clear
      end
    end

    private

    def expand_links
      areas.each do |area|
        area.connections.map!{|a| parse_area("#{area.type} #{a}") }
      end
    end

    def validate
      areas.each do |a|
        a.connections.each do |c|
          unless c.connections.include?(a)
            raise Error, "Missing '#{a.type}' connection from #{c} to #{a}"
          end
        end
      end
    end

    def input_province(owner, element)
      id = element.attribute("id").to_s
      name = element.attribute("name").to_s
      supply = element.elements["supply"]
      supply &&= supply.attribute("pos").to_s.split(/,/).map{|x| x.to_i }
      province = Province.new(self, id, name, supply, owner.definition)
      @provinces[id.downcase] = province
      element.elements.each("area") do |e|
        input_area(province, e)
      end
      if province.supply?
        owner.definition.add_home(province)
        owner.add_province(province)
      end
      if e = element.elements["piece"]
        type = e.attribute("type").to_s
        area_id = province.id + e.attribute("area").to_s
        owner.make_piece("#{type} #{area_id}")
      end
    end

    def input_area(province, element)
      id = element.attribute("id").to_s.downcase
      type = element.attribute("type").to_s.downcase
      connections = element.attribute("connections").to_s.split(/ /)
      coordinates = element.attribute("pos").to_s.split(/ /).map{|c| c.split(/,/).map{|x| x.to_i} }
      if coordinates.size == 0
        raise Error, "Area '#{id}' in province '#{province.id}' (#{type}) must have attribute 'pos' with coordinates for placing a piece and floodfilling."
      end
      area_name = element.attribute("name").to_s
      area = Area.new(type, id, area_name, province, connections, coordinates)
      province.add_area(area)
    end
  end
end
