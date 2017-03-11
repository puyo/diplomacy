require 'gui/gui'

class TurnMap < GUI::Label
  include GUI

  def initialize(parent, game)
    super(parent, '')
    @game = game
    @turn = nil
    @id = nil
    setIconPosition(ICON_BELOW_TEXT)
    setJustify(JUSTIFY_LEFT)
  end

  def set_turn(turn)
    @turn = turn
    @game.output_turn_image(turn)
    @id = @game.id(turn)
    icon = makeIcon(@id, @game.turn_images_path)
    if icon
      icon.create
      setIcon(icon)
    else
      raise RuntimeError, "Could not find map file #{@id}"
    end
    setText(turn.to_s)
  end

  def width
    icon.width
  end

  def height
    icon.height
  end
  
end

