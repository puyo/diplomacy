require_relative './game'
require_relative './turn'

module Diplomacy
  class AreaData
    attr_reader :area
    attr_reader :owner

    def initialize(area, power, turn, enmities)
      @area, @power, @turn = area, power, turn
      @enmities = enmities
      @owner = turn.owner(area.province)

      @value = 0

      @our_pieces = []
      @pieces = {}

      area.province.breadth_first_search do |province, dist|
        break if dist >= 2
        piece = turn.piece(province)
        if piece &&
           (piece.area.connections.map(&:province).include?(area.province) ||
            province == area.province)
          if piece.nationality == @power.definition
            @our_pieces.push piece
          else
            @pieces[piece.nationality] = []
            @pieces[piece.nationality].push piece
          end
        end
      end
    end

    attr_reader :value

    def value=(v)
      raise ArgumentError, "Value cannot be a #{v.class}" unless v.is_a?(Numeric)
      if !@value.between?(0, 100_000_000_000_000)
        raise ArgumentError, "Value cannot be #{v}"
      end
      @value = v
    end

    def security
      @our_pieces.size.to_f
    end

    def threat
      @pieces.values.map(&:size).max.to_f
    end

    def basic_value
      result = 0
      if supply?
        result += 1000
        if foreign?
          result += 300 * owner.provinces.size
        elsif home?
          result += 100
        elsif uncontrolled?
          result += 3000
        end
      end
      logical_adjust(result)
    end

    def logical_adjust(value)
      if supply?
        if owned?
          if threat.zero?
            Util.ailog "#{@power.definition}: Reducing value of #{@area} as it is secure"
            value = 0.0 # 0.75
          elsif threat >= security || (threat.positive? && empty?)
            Util.ailog "#{@power.definition}: Increasing value of #{@area} as it is threatened (#{@our_pieces.inspect} < #{threat}, or empty and threatened)"
            value *= 1.5
          end
        elsif security > threat
          Util.ailog "#{@power.definition}: Increasing value of #{@area} as it is not well protected (#{@our_pieces.inspect} > #{threat})"
          value *= 1.5
        elsif security == threat && foreign? && @turn.is_a?(Spring)
          Util.ailog "#{@power.definition}: Reducing value of #{@area} as it is protected in Spring"
          value *= 0.90
        end
      end
      value
    end

    def empty?
      @turn.piece(@area.province).nil?
    end

    def occupied?
      piece = @turn.piece(@area.province)
      piece && piece.nationality == @power.definition
    end

    def enemy_occupied?
      piece = @turn.piece(@area.province)
      piece && piece.nationality != @power.definition
    end

    def owned?
      @owner && @power.definition == @owner.definition
    end

    def home?
      @power.home?(@area.province)
    end

    def foreign?
      @owner && @power.definition != @owner
    end

    def supply?
      @area.province.supply?
    end

    def uncontrolled?
      @owner.nil?
    end
  end

  class DopeyBot < AI
    # --- Class ------------------------------

    PROXIMITY_WEIGHT = {
      Spring => [200, 5000, 100, 80, 65, 50, 40, 35, 30, 25],
      Autumn => [     5000, 100, 80, 65, 50, 40, 35, 30, 25],
    }.freeze

    def initialize
      clear
      @failed_previous_orders = {}
      @enmities = nil
    end

    # --- Queries ----------------------------

    attr_accessor :director

    def turn_enmities=(enmities)
      @enmities = enmities.dup
      @enmities.each do |to, val|
        val += 0.5
        @enmities[to] = val * val * val
      end
    end

    def nationality
      @power.definition
    end

    def maximum_value(type = nil)
      values = if type.nil?
                 @area_data.values
               else
                 @area_data.values.find_all { |d| d.area.type == type }
               end
      values.map(&:value).max.to_f
    end

    def pieces_moving_to(province)
      @orders.find_all do |_, o|
        (o.respond_to?(:destination) && o.destination.province == province) ||
          (!o.is_a?(MoveOrder) && o.piece.area.province == province)
      end
    end

    def orders_with_destinations
      @orders.find_all { |_, o| o.respond_to?(:destination) }
    end

    def available_pieces
      @power.pieces - @orders.map { |p, _| p }
    end

    # --- Commands ---------------------------

    def clear
      @turn = @game = @power = nil
      @area_data = {}
      @possible_orders = {}
      @orders = {}
      @orders_tried = {}
      @objectives = []
    end

    def request_orders(game, power)
      Util.ailog '-------------------------------------------'
      clear
      @turn = power.turn
      @game = game
      @power = power

      if @turn.pieces.empty?
        @power.submit_orders('')
        exit
      end

      @power.pieces.each do |piece|
        @orders_tried[piece] = []
      end

      @turn.map.areas.each do |area|
        @area_data[area] = AreaData.new(area, @power, @turn, @enmities)
      end

      note_previous_results

      case turn = power.turn
      when MovementTurn
        submit_movement_orders(game, power)
      when RetreatTurn
        submit_retreat_orders(game, power)
      when AdjustmentTurn
        submit_adjustment_orders(game, power)
      else
        raise RuntimeError, "Unhandled turn type: #{turn}"
      end

      # output_value_map

      orders_text = @orders.values.map(&:text).join("\n")
      Util.ailog orders_text

      begin
        power.submit_orders(orders_text)
      rescue Diplomacy::Error => e
        Util.ailog "Error submitting orders: #{e}"
        orders_text = ''
        Util.ailog "Retrying:\n#{orders_text}"
        retry
      rescue StandardError => e
        Util.ailog "Error submitting orders: #{e}"
        power.submit_orders('')
      end
      Util.ailog '-------------------------------------------'
    end

    def key(turn)
      case turn
      when Diplomacy::MovementTurn
        turn.class
      when Diplomacy::AdjustmentTurn
        Autumn
      when Diplomacy::RetreatTurn
        turn.next_turn_type
      end
    end

    def note_previous_results
      previous_turn = @game.previous_turn
      if previous_turn.is_a?(MovementTurn)
        previous_orders = previous_turn.power(nationality).orders
        key = @game.previous_turn.class
        prev_key = key(@game.previous_turn)
        @failed_previous_orders[prev_key] = previous_orders.reject(&:successful?)
        @failed_previous_orders[prev_key].map!(&:text)
        Util.log "Previous orders of #{@power.definition} on turn type #{key} which failed:"
        Util.log @failed_previous_orders[prev_key].join("\n")

        inform_director if director
      end
    end

    def inform_director
      previous_orders = @game.previous_turn.power(nationality).orders
      previous_orders.each do |order|
        if order.respond_to?(:target) &&
           !order.target.nil? &&
           order.target.nationality != nationality
          if order.target.dislodged?
            director.piece_dislodged(order.piece, order.target)
          else
            director.piece_attacked(order.piece, order.target)
          end
        end
      end
    end

    def calculate_values(key)
      distribute_values(key)
      normalize_values
      print_data
    end

    def distribute_values(key)
      @area_data.each do |area, data|
        value = data.basic_value
        value = enmity_adjust(area, value)
        spread = key == Autumn ? 3 : 4
        spread += (7 - @turn.powers.size) # increase spread as nations are eliminated
        area.breadth_first_search do |dest, dist|
          break if dist > spread
          val = value * PROXIMITY_WEIGHT[key][dist]
          @area_data[dest].value += val
        end
      end
    end

    def enmity_adjust(area, value)
      return value if @enmities.nil?
      data = @area_data[area]
      if data.supply?
        owner = @turn.owner(area.province)
        occupier = @turn.piece(area.province)

        owner = owner.definition if owner
        occupier = occupier.nationality if occupier
        owner_e = @enmities[owner] || 0.5
        occupier_e = @enmities[occupier] || 0.5

        Util.ailog "#{nationality}: Owner of #{area} is #{owner}, which we hate this much: #{owner_e}"
        Util.ailog "#{nationality}: Occupier of #{area} is #{occupier}, which we hate this much: #{occupier_e}"

        scale = owner_e * occupier_e
        Util.ailog "#{nationality}: Scaling value of #{area} by #{scale}"
        value *= scale
      end
      value
    end

    def normalize_values
      max = maximum_value
      @area_data.each do |_area, data|
        data.value = data.value.to_f / max.to_f
      end
    end

    def possible_objectives(pieces = available_pieces)
      return [] if pieces.empty?
      Util.ailog "#{nationality}: Available pieces for next objective = #{pieces.join(', ')}"
      Util.ailog "#{nationality}: Possible objectives:"
      provinces = Turn.reachable_provinces(pieces).to_a
      provinces.reject! do |prov, _pieces|
        nomove = @orders.to_a.find do |p, _o|
          p.nationality == nationality &&
            p.respond_to?(:destination) &&
            p.destination.province == prov &&
            !p.moving?
        end
        nomove
      end
      provinces_to_objectives(provinces)
    end

    def provinces_to_objectives(provinces)
      result = provinces.map do |province, pieces|
        value = 0.0
        types = pieces.map(&:type).uniq
        types.each do |type|
          province.areas(type).each do |area|
            value = [value, @area_data[area].value].max
          end
        end
        value2 = value + rand * value / 4.0
        Util.ailog format('  %s (%.2f [%.2f], %s)', province.inspect, value, value2, pieces.inspect)
        [value2, province, pieces]
      end
      result.sort { |a, b| b[0] <=> a[0] }
    end

    def route_pieces(available, objectives)
      if objectives.empty? || available.empty?
        available.each do |p|
          @orders[p] = HoldOrder.new(turn: @turn, piece: p)
        end
        return
      end
      while !objectives.empty? && !available.empty?
        _value, province, pieces = objectives.first

        if (piece = @turn.piece(province)) &&
           piece.nationality == nationality &&
           @orders[piece] &&
           !@orders[piece].is_a?(MoveOrder)
          next # avoid bumping into it
        end

        data = @area_data[province.areas.first]
        pieces = (pieces & available).sort_by { |p| @area_data[p.area].value }

        used = []
        new_orders = []
        difficulty = data.threat

        piece_there = pieces.find { |p| p.area.province == province }
        if piece_there
          pieces.delete piece_there
          pieces.unshift piece_there
          difficulty -= 1.0
        end

        Util.ailog "#{nationality}: Trying objective #{province}, difficulty #{difficulty}..."

        while !pieces.empty? && used.size.to_f <= difficulty
          piece = pieces.shift
          Util.ailog "#{nationality}: #{piece.inspect} -> #{province}"

          if province == piece.area.province
            order = HoldOrder.new(turn: @turn, piece: piece)
          else
            dest = province.areas.find { |a| piece.area.connections.include?(a) }
            order = MoveOrder.new(turn: @turn, piece: piece, destination: dest)
          end

          if @failed_previous_orders[key(@turn)].to_a.include?(order.text) && rand(10) >= 8
            next
          else
            new_orders.push order
            used.push piece
          end
        end
        objectives.shift
        available -= used
        new_orders.each { |o| @orders[o.piece] = order }
      end
    end

    def generate_moves
      @orders = {}
      attempts = 0
      while !available_pieces.empty? && attempts < 100
        route_pieces(available_pieces, possible_objectives)
        Util.ailog "#{nationality}: Orders:"
        @orders.each do |_, o|
          Util.ailog o.text
        end
        Util.ailog "#{nationality}: Pieces left: #{available_pieces.join(', ')}"
        Util.ailog "#{nationality}: Objectives left: #{@objectives.map { |obj| obj[1] }.join(', ')}"
        generate_convoys
        generate_supports
        attempts += 1
      end
      if attempts == 100
        puts 'Warning: Gave up retrying orders.'
        Util.ailog 'Warning: Gave up retrying orders. Results:'
        @orders.each do |_, o|
          Util.ailog '  ' + o.text
        end
      end
    end

    def generate_supports
      @orders.each do |_piece, order|
        next unless order.respond_to?(:destination)
        dest = order.destination.province
        pieces = pieces_moving_to(dest)
        next if pieces.size < 2
        Util.ailog "#{nationality}: Bounce detected! Pieces #{pieces.map(&:first).join(' and ')} are moving to #{dest}. Generating supports..."

        # Pick the N-1 pieces with the lowest threats and make them support moves.

        # A conundrum - move the piece with the lowest value or the highest threat?

        #					sorted = pieces.sort_by{|p,o| @area_data[p.area].value/(@area_data[p.area].threat+1) }
        #					sorted = pieces.sort_by{|p,o| @area_data[p.area].value }
        sorted = pieces.sort_by do |p, o|
          val = @area_data[p.area].value
          if o.is_a?(ConvoyedMoveOrder)
            val -= 1000.0
          end
          val
        end

        existing_piece = pieces.find { |p, _o| p.area.province == dest }
        if existing_piece
          moving_piece = existing_piece
          sorted.delete existing_piece
        else
          moving_piece = sorted.pop
        end

        Util.ailog 'Moving piece: ' + moving_piece.inspect
        Util.ailog 'Supports    : ' + sorted.inspect

        moving_pieces = []
        if moving_piece.last.is_a?(ConvoyOrder)
          # If possible, support the piece being
          # convoyed in preference to the convoy itself.
          convoying_piece = moving_piece
          convoyed_piece = convoying_piece.last.piece_convoyed
          convoyed_order = @orders[convoyed_piece]
          moving_pieces = [[convoyed_piece, convoyed_order], convoying_piece]
        else
          moving_pieces = [moving_piece]
        end

        sorted.each do |piece, _order|
          changed = false
          moving_pieces.each do |this_moving_piece, moving_order|
            dest = if moving_order.respond_to?(:destination)
                     moving_order.destination.province
                   else
                     moving_piece.area.province
                   end
            if !piece.area.connections.find { |c| c.province == dest }
              next
            end
            support_order = SupportOrder.new(turn: @turn, piece: piece, supported_piece: this_moving_piece)
            if !@orders_tried[piece].include?(support_order.text)
              change_order(piece, support_order)
              changed = true
            end
          end
          if !changed
            hold_order = HoldOrder.new(turn: @turn, piece: piece)
            change_order(piece, hold_order)
          end
        end
      end
    end

    def generate_convoys
      @orders.each do |piece, order|
        next if !order.respond_to?(:destination)
        next if piece.type != 'f' || !piece.area.province.areas('a').empty?
        fleet = piece
        Util.ailog "#{nationality}: Generating convoy orders..."
        Util.ailog "#{nationality}: fleet = #{fleet}"
        provinces = Turn.reachable_provinces([fleet])
        areas = provinces.map { |prov, _pieces| prov.areas('a') }.flatten
        armies = @orders.find_all do |_piece, p_order|
          piece.type == 'a' &&
            areas.include?(piece.area) &&
            (p_order.is_a?(MoveOrder) || p_order.is_a?(HoldOrder))
        end
        armies = armies.sort_by { |_piece, p_order| @area_data[p_order.destination].value }

        # if there's an army which may be convoyed to a place
        # more valuable than (its current destination + the
        # fleet's destination - the fleet's current location),
        # then make an appropriate convoy order for the pair

        fleet_value = @area_data[order.destination].value - @area_data[fleet.area].value
        Util.ailog "#{nationality}: Current fleet value = #{fleet_value}"
        Util.ailog "#{nationality}: Armies = #{armies.map { |_p, o| o }.join(', ')}"
        armies.each do |army, army_order|
          next_fleet = false
          current_army_value = @area_data[army_order.destination].value
          Util.ailog "#{nationality}: Current army value = #{current_army_value}"
          areas.each do |area|
            already_there = area.province == army.area.province
            already_moving_there = area.province == army_order.destination.province
            can_move_there_itself = army.area.connections.include?(area)
            other_pieces = pieces_moving_to(area.province).reject { |p, _o| p == fleet }

            if other_pieces.empty? && !already_moving_there && !can_move_there_itself && !already_there
              potential_army_value = @area_data[area].value
              Util.ailog "#{nationality}: #{army} value(#{area}) = #{potential_army_value}"
              if potential_army_value > current_army_value + fleet_value
                make_convoy_order(fleet, army, area)
                next_fleet = true
                break
              end
            else
              Util.ailog "#{nationality}: #{army} not being convoyed to #{area}: "
              Util.ailog "Piece(s): #{other_pieces.join(', ')} already moving there" if !other_pieces.empty?
              Util.ailog 'Can move there itself' if can_move_there_itself
              Util.ailog 'Already moving there' if already_moving_there
              Util.ailog 'Already there' if already_there
            end
          end
          break if next_fleet
        end
      end
    end

    def make_convoy_order(fleet, army, destination)
      Util.ailog "#{nationality}: Making convoy order: #{fleet} C #{army} -> #{destination}"
      fo = ConvoyOrder.new(turn: @turn, piece: fleet, piece_conveyed: army, piece_destination: destination)
      ao = ConvoyedMoveOrder.new(turn: @turn, piece: army, path: [fleet.area], destination: destination)
      unless @orders_tried[army].include?(ao.text)
        change_order(fleet, fo)
        change_order(army, ao)
      end
    end

    def change_order(piece, neworder)
      oldorder = @orders[piece]
      @orders[piece] = neworder
      @orders_tried[piece].push neworder.text
      if oldorder.nil?
        return
      end

      Util.ailog "#{piece}: Changing order from #{oldorder} to #{neworder}"

      here = piece.area.province

      newprov = if neworder.respond_to?(:destination)
                  neworder.destination.province
                else
                  here
                end

      oldprov = if oldorder.respond_to?(:destination)
                  oldorder.destination.province
                else
                  here
                end

      if newprov != oldprov
        redo_orders = @orders.find_all do |_p, o|
          (o.respond_to?(:destination) && o.destination.province == here) ||
            (o.is_a?(SupportOrder) && o.supported_piece == piece)
        end
        redo_pieces = redo_orders.map { |p, _o| p }

        Util.ailog "#{piece}: Redoing pieces #{redo_pieces.join(', ')}"

        redo_pieces.each do |p, _o|
          @orders.delete p
        end
      end
    end

    def generate_retreats
      pieces = @power.pieces_dislodged.sort_by { rand }
      Util.ailog "#{nationality}: Dislodged pieces = #{pieces.join(', ')}"
      pieces.each do |piece|
        destinations = piece.retreats.sort_by { |a| -@area_data[a].value }
        @possible_orders[piece] = []
        destinations.each do |dest|
          @possible_orders[piece].push RetreatOrder.new(@turn, piece, dest)
        end
        @possible_orders[piece].push DisbandOrder.new(@turn, piece) # always a possibility...
        Util.ailog "POSSIBLE ORDERS(#{piece}) = #{@possible_orders[piece].join(', ')}"

        @orders[piece] = @possible_orders[piece].shift
      end
      redirect_retreat_bounces
    end

    def redirect_retreat_bounces
      loop do
        changed = false
        retreat_orders = @orders.values
                           .find_all { |o| o.is_a?(RetreatOrder) }
                           .sort_by { |o| @area_data[o.destination].value }
        retreat_orders.each_with_index do |order, index|
          piece = order.piece
          other_orders = retreat_orders[index + 1, retreat_orders.size]
          next if !other_orders.find { |o| o.destination == order.destination }
          # Redirect this less valuable piece's retreat...
          @orders[piece] = @possible_orders[piece].shift
          changed = true
        end
        break if !changed
      end
    end

    def generate_adjustments
      diff = @turn.adjustments[nationality]
      Util.ailog "#{nationality}: Diff = #{diff}"
      if diff.positive?
        generate_builds(diff)
      elsif diff.negative?
        generate_disbands(-diff)
      end
    end

    def generate_builds(num)
      available_homes = nationality.homes.find_all { |p| @turn.piece(p).nil? && @turn.owner(p).definition == nationality }
      Util.ailog "#{nationality}: Available homes = #{available_homes.join(', ')}"
      areas = Turn.reachable_provinces(available_pieces).map { |prov, _pieces| prov.areas }.flatten
      areas_by_type = {}
      sum = 0.0
      areas.each do |area|
        areas_by_type[area.type] = 0.0 if areas_by_type[area.type].nil?
        val = @area_data[area].value
        areas_by_type[area.type] += val
        sum += val
      end
      homes_left = available_homes
      times_tried = 0
      while num.positive? && !homes_left.empty? && times_tried < 20
        Util.ailog "#{nationality}: Choosing what to build"
        roll = rand * sum
        Util.ailog "#{nationality}: Rolled #{roll} vs. #{sum}"
        count = 0.0
        build_type = 'a'
        areas_by_type.each do |type, total_value|
          count += total_value
          next if roll > count
          build_type = type
          Util.ailog "#{nationality}: #{roll} < #{count}, build type = #{type}"
          break
        end
        homes_left.each do |home|
          areas = home.areas(build_type)
          next if areas.empty?
          area = areas.first
          area_free = @orders.find { |a, _o| a.province == area.province }.nil?
          next if !area_free
          @orders[area] = BuildOrder.new(power: @power, area: area)
          homes_left.delete area.province
          num -= 1
          Util.ailog "#{nationality}: Building #{build_type} in #{area}, #{num} builds left"
          break
        end
        times_tried += 1
      end
    end

    def generate_disbands(num)
      pieces = @power.pieces
      worst_pieces = pieces.sort_by { |p| @area_data[p.area].value }
      num.times do
        piece = worst_pieces.shift
        @orders[piece] = DisbandOrder.new(turn: @turn, piece: piece)
      end
    end

    def print_data
      reachable = Turn.reachable_provinces(@power.pieces_all)
      @area_data.values.sort_by(&:value).each do |data|
        next unless reachable.include?(data.area.province)
        Util.ailog format('%s: Dest(%s, %30s) = %1.3f', nationality, data.area.type.upcase, data.area.to_s, data.value)
      end
      Util.ailog ''
    end

    def submit_movement_orders(_game, _power)
      Util.ailog "AI power '#{nationality.name}' generating movement orders for turn #{@turn}..."
      calculate_values(key(@turn))
      generate_moves
    end

    def submit_retreat_orders(_game, _power)
      Util.ailog "AI power '#{nationality.name}' generating retreat orders for turn #{@turn}..."
      calculate_values(key(@turn))
      generate_retreats
    end

    def submit_adjustment_orders(_game, _power)
      Util.ailog "AI power '#{nationality.name}' generating adjustment orders for turn #{@turn}..."
      calculate_values(key(@turn))
      generate_adjustments
    end

    # Value map ---------------

    if defined? GD
      def value_maps_path
        File.join(File.dirname(__FILE__), '..', 'turnmaps')
      end

      def value_map_path(type)
        File.join(value_maps_path, "valuemap-#{@game.id(@turn)}-#{@power.definition.adjective.downcase}-#{type}.png")
      end

      def output_value_map
        results = {}
        @game.map.types.each do |type|
          results[type] = load_png(@game.map.base_path)
        end

        maxval = maximum_value
        white = RGB.new('#ffffff')
        black = RGB.new('#000000')

        results.each do |type, result|
          @turn.map.provinces.each do |province|
            value = 0
            areas = province.areas(type)
            if !areas.empty?
              areas.each do |area|
                value += @area_data[area].value
              end
              value = value.to_f / areas.size
              value /= maxval if maxval != 0.0
              colour = white * value
              colidx = result.colorResolve(colour.hex)
              areas.each do |area|
                area.coordinates.each do |x, y|
                  result.fill(x, y, colidx)
                end
              end
            else
              province.paint_coordinates.each do |x, y|
                result.fill(x, y, result.colorResolve(black.hex))
              end
            end
          end
        end

        piece_icons = {}
        @game.map.types.each do |type|
          piece_icons[type] = load_png(@game.piece_icon_path(type))
        end

        results.each do |_type, result|
          @game.paint_arrows(@turn, result, @orders.values)
        end

        @turn.pieces.each do |piece|
          resource_col = piece.nationality.resource_colour
          x, y = piece.area.coordinates[0]
          icon = piece_icons[piece.type]
          pw, ph = icon.width, icon.height
          results.each do |_type, result|
            icon.copy(result, x - pw / 2, y - ph / 2, 0, 0, pw, ph)
            result.fill(x, y, result.colorResolve(resource_col.hex))
          end
        end

        results.each do |type, result|
          save_png(result, value_map_path(type))
        end
      end

      def load_png(path)
        File.open(path, 'rb') do |f|
          Util.log "Reading '#{path}'..."
          return GD::Image.newFromPng(f)
        end
      end

      def save_png(image, path)
        File.open(path, 'wb') do |f|
          Util.log "Writing '#{path}'..."
          image.png(f)
        end
      end
    end
  end
end
