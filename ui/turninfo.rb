require 'gui/gui'

class TurnInfo < GUI::Text
	include GUI

	def initialize(parent, game)
		@game = game
		@turn = nil
		super(parent, nil, 0, TEXT_READONLY|TEXT_WORDWRAP)
		disable
	end

	def update
		set_turn(@turn)
	end

	def set_turn(turn)
		@turn = turn
		if turn.current?
			setText(turn.situation)
		else
			setText(turn.results)
		end
	end

	def defaultHeight
		200
	end
end
