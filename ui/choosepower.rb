require 'gui/gui'

class ChoosePower < GUI::DialogBox
  include GUI

  def initialize(app)
    super(app, "Choose Power")
    app.game.power_definitions.each do |power|
      b = Button.new(self, power.name)
      b.width = 200
      b.backColor = GUI.rgb(power.province_colour.value)
      b.textColor = GUI.rgb(0x000000)
      b.layoutHints = LAYOUT_FIX_WIDTH|LAYOUT_CENTER_X

      b.connect(SIGNAL_COMMAND) do
        hide
        app.power_selected(power)
      end
    end
    c = CancelButton.new(self)
    c.layoutHints = LAYOUT_RIGHT

    connect(SIGNAL_CLOSE) { app.exit }
    c.connect(SIGNAL_COMMAND) { app.exit }
  end
end
