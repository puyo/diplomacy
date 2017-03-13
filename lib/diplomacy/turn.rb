require_relative './util'

module Diplomacy
  # Game state.
  class Turn
    # --- Class ------------------------------

    def initialize(map:, previous_turn: nil)
      @game = nil
      @map = map
      @contenders = Hash.new { |h, k| h[k] = [] }
      @pieces = {}
      @pieces_dislodged = {}
      if previous_turn
        @game = previous_turn.game
        @year = previous_turn.next_year
        @powers = previous_turn.powers.map do |power|
          if power.pieces_all.empty?
            nil
          else
            newpower = Turn::Power.new(self, power.definition)
            power.provinces.each do |p|
              newpower.add_province(p)
            end
            newpower
          end
        end.compact
      elsif map
        @year = map.first_year
        @powers = []
      else
        raise ArgumentError, 'Inadequate info to create turn'
      end
    end

    # A hash of reachable provinces this turn to the pieces which
    # could move to that province.
    def self.reachable_provinces(pieces)
      result = Hash.new { |h, k| h[k] = [] }
      pieces.each do |piece|
        result[piece.area.province].push piece
        piece.area.connections.each do |area|
          result[area.province].push piece
        end
      end
      result
    end

    # --- Queries ----------------------------

    attr_reader :map, :year
    attr_accessor :year
    attr_accessor :game

    def current?
      if @game
        self == @game.current_turn
      else
        false
      end
    end

    def previous_turn
      if @game
        i = @game.turns.index(self)
        raise Error, 'Turn not found in game!' if i.nil?
        game.turns[i - 1]
      end
    end

    def to_s
      [season, year, game].join(' ')
    end

    def id
      [year, type_id].join('-')
    end

    def inspect
      results
    end

    def results
      result = 'TURN: '
      result << to_s << "\n\n"
      result << @powers.map(&:inspect).join
      result
    end

    def situation
      result = 'TURN: '
      result << to_s << "\n\n"
      powers.each do |power|
        result << power.definition.name << ': '
        result << power.pieces.join(', ') << "\n"
      end
      result << "\n"
      powers.each do |power|
        piececount = power.pieces_all.size
        supplycentrecount = power.supply_centres.size
        result << "#{power.definition}: #{piececount}/#{supplycentrecount}" << "\n"
      end
      result
    end

    def adjustments?
      !adjustments.empty?
    end

    def adjustments
      result = Hash.new(0)
      powers.each do |power|
        piececount = power.pieces_all.size
        supplycentrecount = power.supply_centres.size
        Util.log "#{power.definition}: #{piececount}/#{supplycentrecount}"
        diff = supplycentrecount - piececount
        result[power.definition] = diff if diff != 0
      end
      result
    end

    def orders(power = nil)
      if power
        power(power).orders
      else
        powers.map(&:orders).flatten
      end
    end

    def idle_powers
      playing_powers.reject(&:submitted?)
    end

    def playing_powers
      @powers.reject { |p| p.definition.is_a?(Uncontrolled) || p.definition.player.nil? }
    end

    def powers
      @powers.reject { |p| p.definition.is_a?(Uncontrolled) }
    end

    def piece(place, type = nil, piecehash = @pieces)
      case place
      when Area
        piecehash[place]
      when Province
        piecehash.values.find { |p| p.area.province == place }
      when String
        piecehash[@map.parse_area(place, type)]
      end
    end

    def pieces(power = nil)
      if power
        power(power).pieces
      else
        @pieces.values.flatten
      end
    end

    def piece_dislodged(place, type = nil)
      piece(place, type, @pieces_dislodged)
    end

    def pieces_dislodged(power = nil)
      if power
        power(power).pieces_dislodged
      else
        @pieces_dislodged.values.flatten
      end
    end

    def piece_owner?(text, owner)
      parse_piece(owner, text, true)
    rescue Error
      false
    end

    def power(arg)
      case arg
      when Diplomacy::Power
        @powers.find { |p| p.definition == arg }
      when Turn::Power
        power(arg.definition)
      else
        raise ArgumentError, "Argument type passed to #{self.class}#power invalid: #{arg.class}"
      end
    end

    def parse_piece(power, text, mine = false)
      area = map.parse_area(text)
      results = pieces.find_all { |p| p.area == area }
      if mine
        results.delete_if { |p| p.nationality != power.definition }
      end
      if results.empty?
        raise Error, "No such piece '#{text}'. Your pieces are:\n#{power.pieces.join("\n")}"
      end
      if results.size > 1
        raise RuntimeError, 'You have 2 pieces in one province!'
      end
      results.first
    end

    def parse_dislodged_piece(power, text, mine = true)
      area = map.parse_area(text)
      result = @pieces_dislodged[area]
      if result.nil?
        raise Error, "No such dislodged piece '#{text}'. Your pieces are:\n#{power.pieces_dislodged.join("\n")}"
      end
      return nil if mine && result.owner != power
      result
    end

    def opponents(province, attacker)
      result = @contenders[province]
      # Util.log "  attackers(#{province}) = #{result.map{|p| "#{p} (#{p.strength})"}.join(', ')}"
      if (piece = piece(province)) && !piece.moving?
        newpiece = piece.dup
        newpiece.supports = []
        result |= [newpiece]
      end
      # Util.log "  contenders(#{province}) = #{result.map{|p| "#{p} (#{p.strength})"}.join(', ')}"
      result = maxes(result, &:strength)
      result.delete_if { |p| p.to_s == attacker.to_s }
      # Util.log "  opponents(#{province}) = #{result.map{|p| "#{p} (#{p.strength})"}.join(', ')}}"
      result
    end

    def maxes(array, &block)
      result = []
      max_value = array.map(&block).max
      array.each do |element|
        result << element if yield(element) == max_value
      end
      result
    end

    def owner(province)
      @powers.find { |p| p.provinces.include?(province) }
    end

    def adjacent_pieces(province)
      result = []
      province.adjacent_provinces.each do |connection|
        piece = piece(connection)
        can_attack = (piece && piece.area.connections.map(&:province).include?(province))
        result.push(piece) if can_attack
      end
      result
    end

    # --- Commands ---------------------------

    def parse_order(power, text, mine = true)
      text = text.strip.downcase
      self.class::ORDER_TYPES.each do |order|
        if data = order::REGEXP.match(text)
          return order.parse(power, data, mine)
        end
      end
      raise Error, "Order '#{text}' not recognised for turn #{self}"
    end

    def add_piece(piece)
      if existing = @pieces[piece.area] && existing.nationality != piece.nationality && piece.id != existing.id
        raise Error, "Already a piece there: #{existing}, cannot add piece: #{piece}"
      end
      piece.owner.add_piece(piece)
      @pieces[piece.area] = piece
    end

    def add_piece_dislodged(piece)
      if @pieces_dislodged[piece.area]
        #				raise Error, "Already a piece there: #{existing}, cannot add dislodged piece: #{piece}"
      end
      piece.owner.add_piece_dislodged(piece)
      @pieces_dislodged[piece.area] = piece
    end

    def remove_piece(piece)
      area = piece.area
      Util.log "#{piece}: Removing from #{self} (#{area.province})..."
      if @pieces_dislodged[area] == piece
        @pieces_dislodged.delete area
      end
      if @pieces[piece.area] == piece
        @pieces.delete area
      end
      power(piece.owner).remove_piece(piece)
    end

    def add_power(power)
      @powers.push power
    end

    def add_order(_order)
      raise Error, 'Abstract'
    end

    def remove_order(_order)
      raise Error, 'Abstract'
    end

    def clear_pieces
      @pieces.clear
      @pieces_dislodged.clear
      @powers.each do |power|
        power.pieces.clear
      end
    end

    def submit_orders(power, text)
      power = power(power)
      orders = []
      begin
        text.each_line do |line|
          next if line.strip == ''
          order = parse_order(power, line, true)
          orders << order
        end
        orders.each do |order|
          add_order(order)
        end
      rescue StandardError => e
        raise Error, e.message, e.backtrace
      end

      if @game && @game.nice_mode
        ok = true
        orders.each do |order|
          order.validate
          ok = false unless order.successful?
        end
        if !ok
          orders.each { |order| remove_order(order) }
          raise Error, orders.join(', ')
        end
      end

      power.submitted = true
    end

    def build_piece(owner, area)
      piece = Piece.new(turn: self, type: area.type, owner: owner, area: area)
      add_piece(piece)
      piece
    end

    def make_piece(owner, text)
      build_piece(owner, @map.parse_area(text))
    end

    def copy_piece_to(piece, area)
      area ||= piece.area
      owner = power(piece.owner.definition)
      piece = Piece.new(turn: self, type: piece.type, owner: owner, area: area, identifier: piece.identifier)
      Util.log "Adding piece #{piece} to turn #{self}..."
      add_piece(piece)
      if area.province.supply? && (is_a?(@map.first_season) || is_a?(AdjustmentTurn))
        claim_province(area.province, piece.owner)
      end
    end

    def copy_piece_dislodged(piece, area)
      owner = power(piece.owner.definition)
      newpiece = Piece.new(turn: self, type: piece.type, owner: owner, area: area, identifier: piece.identifier)
      newpiece.retreats.replace(piece.retreats)
      Util.log "Adding dislodged piece #{newpiece} to turn #{self}..."
      add_piece_dislodged(newpiece)
    end

    def add_contender(province, piece)
      @contenders[province].push piece
    end

    def remove_contender(province, piece)
      @contenders[province].delete piece
      # Util.log "#{piece}: Removed contention for #{province}, contenders(#{province}) = #{@contenders[province].map{|p| "#{p} (#{p.strength})}".join(', ')
    end

    def claim_province(province, newowner)
      if (oldowner = owner(province)) && oldowner != newowner
        game.province_captured(province, oldowner, newowner) if is_a?(AdjustmentTurn)
        oldowner.remove_province(province)
      end
      newowner.add_province(province)
    end

    def order_validated(order)
      # Do nothing by default
    end

    # Empty by default but may be overridden
    def orders_template(_power_definition)
      ''
    end

    private

    def orders_fill
      Util.log "FILLING IN DEFAULT ORDERS FOR TURN #{self}"
      @powers.each do |power|
        power.unordered_pieces.each do |piece|
          order = default_order(piece)
          Util.log "  #{order}"
          piece.order = order
        end
      end
    end

    def orders_validate
      Util.log "VALIDATING #{self}"
      @powers.each do |power|
        power.orders.each do |order|
          order.validate
          order_validated(order) if order.successful?
          Util.log "  #{order}"
        end
      end
    end
  end
end

require_relative './movement_turn'
require_relative './adjustment_turn'
require_relative './retreat_turn'
