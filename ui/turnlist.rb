require 'gui/gui'

class TurnList < GUI::TreeList
  include GUI

  def initialize(parent, game)
    @game = game
    @last_item_added = nil
    super(parent, 0, nil, 0, TREELIST_BROWSESELECT|TREELIST_SHOWS_LINES)
    setPad(0)
    setLayoutHints(LAYOUT_FILL_Y|LAYOUT_FIX_WIDTH)
    setWidth(200)
  end

  def add_turn(turn=@game.current_turn)
    if turn.previous_turn
      @game.reoutput_turn_image(turn.previous_turn)
      app.mainWindow.mapdisplay.set_turn(turn.previous_turn)
    end

    # Prepare next turn for the player

    @game.output_turn_image(turn)
    item = addItemLast(nil, @game.turn.to_s, nil, nil, turn)
    @last_item_added = item
    return item
  end

  def select_last_item_added
    selectItem(@last_item_added, true)
  end
end
