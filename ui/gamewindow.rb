require 'gui/gui'
require 'drawmap'

require 'turninfo'
require 'turnlist'
require 'turnmap'

class GameWindow < GUI::MainWindow
  include GUI

  def initialize(app)
    super(app, "Diplomacy: #{app.game.name}")

    # Window body
    #
    # body v
    # -----
    # -----
    # | | | middle >
    # -----
    # -----
    #
    body = VerticalFrame.new(self)
    body.setLayoutHints(LAYOUT_FILL_BOTH)
    body.setPad(0)
    body.setVSpacing(0)

    middle = HorizontalFrame.new(body)
    infoframe = Frame.new(body, "Information")
    infoframe.setFrameStyle(FRAME_SUNKEN)
    infoframe.setLayoutHints(LAYOUT_FILL_X|LAYOUT_FIX_HEIGHT)
    infoframe.setHeight(300)
    @info = TurnInfo.new(infoframe, app.game)
    @info.setLayoutHints(LAYOUT_FILL_BOTH)

    # middle

    turnframe = VerticalFrame.new(middle, LAYOUT_FILL_BOTH|FRAME_SUNKEN)
    turnframe.backColor = GUI.rgb(0xffffff)
    @turnlist = TurnList.new(turnframe, app.game)
    @turnlist.backColor = GUI.rgb(0xffffff)

    @mapframe = VerticalFrame.new(middle, FRAME_SUNKEN)
    @mapdisplay = TurnMap.new(@mapframe, app.game)

    right = VerticalFrame.new(middle)

    @orders_label = Label.new(right, '')
    @ordersframe = HorizontalFrame.new(right)
    @ordersframe.setBackColor(GUI.rgb(0xffffff))
    @ordersframe.setFrameStyle(FRAME_SUNKEN)
    @orders = Text.new(@ordersframe)
    @orders.width = 200
    @orders.height = 300
    @orders.layoutHints = LAYOUT_FIX_BOTH
    @orders.backColor = GUI.rgb(0xffffff)

    submit_orders = Button.new(right, "&Submit")
    most_recent_turn = Button.new(right, "Most &Recent Turn")

    @orders.setFocus

    # Connections

    @turnlist.connect(SIGNAL_SELECTED) do |turnlist, num, item|
      turn = item.data
      @mapdisplay.set_turn(turn)
      @info.set_turn(turn)
    end

    @turnlist.connect(SIGNAL_CHANGED) do |turnlist, num, item|
      set_orders_enabled(item.data.current?)
    end

    submit_orders.connect(SIGNAL_COMMAND) do
      app.orders_submitted(@orders.text)
      @orders.setFocus
    end

    most_recent_turn.connect(SIGNAL_COMMAND) do
      @turnlist.select_last_item_added
      set_orders_enabled(true)
    end

    self.connect(SIGNAL_CLOSE) { exit }

    app.game.connect(:advance, self, :game_advanced)

    first_turn = app.game.map.first_turn
    @turnlist.add_turn(first_turn)
    @mapdisplay.set_turn(first_turn)
    @info.set_turn(first_turn)

    @power = nil
  end

  def set_orders_enabled(value)
    if value
      @ordersframe.backColor = @orders.backColor = GUI.rgb(0xffffff)
      @orders.enable
      @orders.setFocus
    else
      @ordersframe.backColor = @orders.backColor = self.backColor
      @orders.disable
    end
  end

  def power_selected(power)
    @power = power
    @orders_label.text = "#{power}'s orders:"
  end

  def game_started
    # nothing
    @orders.text = app.game.turn.orders_template(@power)
  end

  def game_advanced(game)
    puts "Game advanced to #{game.turn}"
    turn = @turnlist.add_turn
    @info.update
    @orders.text = app.game.turn.orders_template(@power)
    set_orders_enabled(false)
  end

  attr :orders
  attr :orders_label

  attr :mapdisplay
end
