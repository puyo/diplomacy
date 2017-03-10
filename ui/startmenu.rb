require 'gui/gui'

class StartMenu < GUI::DialogBox
	include GUI

	def initialize(app)
		super(app, "Diplomacy Thesis")
		newsurvey = Button.new(self, "&New Survey")
		newsurvey.layoutHints = LAYOUT_CENTER_X
		newsurvey.connect(SIGNAL_COMMAND) do
			hide
			app.new_survey
		end
		h = HorizontalFrame.new(self)
		h.layoutHints = LAYOUT_CENTER_X
		
		label = Label.new(h, "Continue survey ID:")
		surveyid = TextField.new(h, 10)
		continuesurvey = Button.new(h, "&OK")
		continuesurvey.connect(SIGNAL_COMMAND) do
			hide
			app.continue_survey(surveyid.text)
		end
		c = CancelButton.new(self)
		c.layoutHints = LAYOUT_RIGHT

		connect(SIGNAL_CLOSE) { app.exit }
		c.connect(SIGNAL_COMMAND) { app.exit }
	end
end
