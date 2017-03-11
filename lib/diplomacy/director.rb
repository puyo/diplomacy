require_relative './game'
require_relative './turn'
require_relative './common'
require 'fileutils'

module Diplomacy
  # Class for an object dedicated to monitoring a human player.
  # Manipulates the bots' heuristics to hopefully make things more
  # enjoyable for the human player. AKA a player model for player
  # enjoyment.
  class Director

    EnmityRange = (0.01)..(0.99)
    FearRate = 0.2

    def initialize(game, human_nationality)
      @turn = game.map.first_turn
      @game = game
      @nationality = nationalities.find{|n| n == human_nationality }

      if @nationality.nil?
        raise Error, "Could not find a human player #{human_nationality} among: #{nationalities.map{|n| n.player.class }.inspect}"
      end

      bots.each{|bot| bot.director = self }

      ailog "Director: Started for player #{human_nationality}..."

      FileUtils.rm_f "enmities-#{@game.name}-*.txt"
      FileUtils.rm_f "size-#{@game.name}.txt"

      init_relationships(@enmity = {})
      @enmity.each do |from, enmities|
        enmities.each do |to, value|
          enmities[to] = 0.5
        end
      end
      scale_enmities(1.0, *nationalities)
      log_enmities

      apply_enmity_to_bots
    end

    attr_reader :turn, :nationality

    def power
      @turn.power(@nationality)
    end

    def limit_enmities
      @enmity.each do |from, enmities|
        enmities.each do |to, value|
          enmities[to] = [[value, EnmityRange.first].max, EnmityRange.last].min
        end
      end
    end

    def output_plot_data
      nations = @game.map.power_definitions.sort_by{|n| n.name }
      nations.each do |nat|
        enmities = @enmity[nat] || {}
        data = nations.map{|n| enmities[n].to_f }
        fname = "enmities-#{@game.name}-#{nat.adjective}.txt"
        File.open(fname, "a") do |f|
          f.puts data.join(" ")
        end
      end

      fname = "size-#{@game.name}.txt"
      File.open(fname, "a") do |f|
        nations = @game.map.power_definitions.sort_by{|n| n.name }
        data = nations.map{|n| @turn.power(n).provinces.size rescue 0.0 }
        f.puts data.join(' ')
      end
    end

    def log_enmities(nationality=nil)
      if nationality.nil?
        @enmity.each do |nat, enmities|
          log_enmities(nat)
        end
      else
        ailog "Director: Enmities(#{nationality}):\n  " +
              @enmity[nationality].to_a.sort_by{|n,e| -e}.map{|n,e| format("%s: %.2f", n.name, e) }.join("\n  ")
      end
    end

    def log_enmities_towards(nat)
      toprint = {}
      @enmity.each do |from, enmities|
        toprint[from] = enmities[nat] unless from == nat
      end
      ailog "Director: EnmitiesTowards(#{nat}):\n  " +
            toprint.to_a.sort_by{|n,e| -e}.map{|n,e| format("%s: %.2f", n.name, e) }.join("\n  ")
    end

    def piece_attacked(piece, target)
      ailog "Director: #{piece} ATTACKED #{target}"
      ailog "Director: BEFORE:"
      log_enmities(target.nationality)
      log_enmities(piece.nationality)
      @enmity[target.nationality][piece.nationality] *= 2
      @enmity[piece.nationality][target.nationality] *= 1.25
      scale_enmities(1.0, piece.nationality, target.nationality)
      ailog "Director: AFTER:"
      log_enmities(target.nationality)
      log_enmities(piece.nationality)
    end

    def piece_dislodged(piece, target)
      ailog "Director: #{piece} DISLODGED #{target}"
      ailog "Director: BEFORE:"
      log_enmities(target.nationality)
      log_enmities(piece.nationality)
      @enmity[target.nationality][piece.nationality] *= 3
      @enmity[piece.nationality][target.nationality] *= 1.5
      scale_enmities(1.0, piece.nationality, target.nationality)
      ailog "Director: AFTER:"
      log_enmities(target.nationality)
      log_enmities(piece.nationality)
    end

    def province_captured(province, oldowner, newowner)
      ailog "Director: #{newowner} CAPTURED #{oldowner.definition.adjective} #{province}"
      oldnat = oldowner.definition
      newnat = newowner.definition
      ailog "Director: BEFORE:"
      log_enmities(oldnat)
      log_enmities(newnat)
      if oldowner.home?(province)
        @enmity[oldnat][newnat] *= 6
      else
        @enmity[oldnat][newnat] *= 4
      end
      scale_enmities(1.0, oldnat, newnat)
      ailog "Director: AFTER:"
      log_enmities(oldnat)
      log_enmities(newnat)
    end

    def nationalities
      @game.powers.map{|p| p.definition }
    end

    def bot_nationalities
      nationalities - [@nationality]
    end

    def bots
      bot_nationalities.map{|n| n.player }
    end

    def one_at_a_time(array)
      array.each do |a|
        yield a, array - [a]
      end
    end

    def init_relationships(relationships)
      one_at_a_time(nationalities) do |nat,others|
        relationships[nat] = {}
        others.each do |other|
          relationships[nat][other] = 0.0
        end
      end
    end

    def direct(turn)
      ailog "Director: Directing turn #{turn}"
      @turn = turn

      output_plot_data
      remove_dead_powers

      ailog "Director: Enmities at start of turn #{turn}:"
      ailog "--"
      log_enmities
      ailog "--"

      if turn.is_a?(MovementTurn)
        #				promote_challenge # makes it too difficult in practice :-(
        promote_balance
      end

      apply_enmity_to_bots
    end

    def promote_challenge
      ailog "Director: Promoting challenge on turn #{turn}"

      friendly_pieces = power.pieces
      provinces = power.provinces + power.pieces.map{|p| p.area.province }
      pieces = provinces.map{|prov| turn.adjacent_pieces(prov) }.flatten.uniq
      enemy_pieces = pieces.reject{|piece| piece.nationality == nationality }

      ailog "Director: Friendlies = #{friendly_pieces.join(', ')}"
      ailog "Director: Enemies = #{enemy_pieces.join(', ')}:"

      give = rand(2)+1 # let the player have 2-3 pieces unharrassed

      expected = expected_attacks(enemy_pieces)
      piecesperattack = friendly_pieces.size/(expected+give)

      ailog "Director: # Expected attacks = #{expected}:"
      ailog "Director: PiecesPerAttack = #{piecesperattack}:"

      bot_nationalities.each do |from|
        oldval = @enmity[from][nationality]
        our_enmity = @enmity[nationality][from]
        @enmity[from][nationality] = 0.9*oldval + 0.1*(piecesperattack*@enmity[nationality][from])
      end

      scale_enmities(1.0, *nationalities)

      ailog "Director: Enmities after challenge promoted on #{turn}:"
      ailog "--"
      log_enmities
      ailog "--"
    end
    
    def expected_attacks(enemy_pieces)
      enemy_pieces.map{|piece| @enmity[piece.nationality][nationality] }.sum
    end

    def promote_balance
      @enmity.each do |from, enmities|
        enmities.each do |to, value|
          fear = @turn.power(to).provinces.size / 5.0
          fearenmity = fear*(FearRate)
          oldenmity = value*(1.0 - FearRate)
          enmities[to] = oldenmity + fearenmity
        end
      end

      scale_enmities(1.0, *nationalities)

      ailog "Director: Enmities after balance promoted on #{turn}:"
      ailog "--"
      log_enmities
      ailog "--"
    end

    def remove_dead_powers
      dead_nationalities = @enmity.map{|from, enmities| from} - nationalities
      ailog "Director: Removing power(s) #{dead_nationalities.join(', ')}"
      dead_nationalities.each do |dead_nat|
        @enmity.delete dead_nat
        @enmity.each do |from, enmities|
          enmities.delete dead_nat
        end
      end
      if dead_nationalities.size > 0
        scale_enmities(1.0, *nationalities)
      end
    end

    def scale_enmities(desired_length, *nationalities)
      limit_enmities
      nationalities.each do |nat|
        enmities = @enmity[nat]
        
        actual_length = 0.0
        enmities.values.each do |val|
          actual_length += val*val
        end

        actual_length = Math.sqrt(actual_length)
        scale = desired_length.to_f/actual_length.to_f

        ailog "Director: Scaling all enmities from #{nat} by #{scale}"
        enmities.each do |nat2, val|
          oldval = enmities[nat2]
          newval = enmities[nat2] * scale
          enmities[nat2] = newval
          ailog "Director: Enmity(#{nat} -> #{nat2}) changed from #{oldval} to #{newval}"
        end
      end
    end

    def apply_enmity_to_bots
      bot_nationalities.each do |bot_nationality|
        bot_nationality.player.set_turn_enmities(@enmity[bot_nationality])
      end
		end
	end
end
