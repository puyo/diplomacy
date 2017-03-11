require 'test/unit'
require_relative '../lib/diplomacy/game'
require_relative '../lib/diplomacy/util'

class AITest < Test::Unit::TestCase
  include Diplomacy

  def setup
    @game = Game.new('test', 'standard')
    @map = @game.map
    Util.log '----------------------------------------------------------'
    Util.log '----------------------------------------------------------'
    Util.log '----------------------------------------------------------'
    Util.log method_name
    Util.log '----------------------------------------------------------'
    Util.log '----------------------------------------------------------'
    Util.log '----------------------------------------------------------'
  end

  attr_reader :game, :map

  def turn
    @game.turn
  end

  def previous_turn
    @game.previous_turn
  end

  def history
    game.turns.map(&:inspect).join("\n-----\n")
  end

  def test_directorless
    game.name = 'directorless'
    game.start
    assert_equal Spring, turn.class
    game.judge
    game.judge
    # game.judge
    # game.judge
    # game.judge
  end

  def test_directorful
    game.name = 'directorful'
    game.power_definition('f').player = Human.new
    game.start
    assert_equal Spring, turn.class
    game.judge
    game.judge
    # game.judge
    # game.judge
  end

  def x_test_directorful_infinite
    # files = Dir[File.join(game.turn_images_path, '*')]
    # files.each do |filename|
    #   File.delete filename
    # end
    game.name = 'directorful'
    game.power_definition('f').player = Human.new
    game.start
    assert_equal Spring, turn.class
    loop do
      game.judge
      puts game.previous_turn.inspect
      # puts '----------------------------------'
      # game.reoutput_turn_image(game.previous_turn)
    end
  end
end
