$LOAD_PATH << File.dirname(__FILE__)
require 'gamewindow'
require 'startmenu'
require 'game'

class DiplomacyApp < GUI::App
  include GUI

  TITLE = 'Diplomacy'
  VENDOR = 'Greg McIntyre'
  ABOUT = "#{TITLE} Judge and AI (c) 2003 #{VENDOR}\n Diplomacy (c) Avalon Hill Game Company, 1979"

  attr :game, :player

  def initialize(game)
    super(TITLE, VENDOR)
    init(ARGV)

    @game = game
    @player = nil
    @power = nil

    create

    @start.show

    puts "Running..."
    run
  end

  def create
    puts 'Creating GUI...'
    @start = StartMenu.new(self)
    main = GameWindow.new(self)

    @game.connect(:start, self, :game_started)

    super
  end

  def new_survey
    @choose = ChoosePower.new(self)
    @choose.create
    @choose.show
  end

  def continue_survey(id)
    puts "Continuing survey #{id}..."

    begin
      data = survey_data(id)

      @player = Diplomacy::Human.new
      power_name = data[:power]
      @power = game.map.power_definitions.find{|p| p.name == power_name }
      puts "Starting game with power '#{@power.name}'..."

      @game.name = data[:game_name]
      mainWindow.title = "Diplomacy: #{@game.name}"

      @game.director_mode = !data[:director_for_first_game]

    rescue Errno::ENOENT => e
      msg = [
        "Invalid survey ID"
      ]
      ErrorDialog.new(mainWindow, msg).execute
      @start.show
      return

    rescue StandardError => e
      msg = [
        "Could not continue survey: ",
        e.message,
      ]
      msg += e.backtrace
      ErrorDialog.new(mainWindow, msg).execute
      @start.show
      return
    end

    start_game
  end

  def randomly_include_director
    @game.director_mode = rand(2) == 0 ? true : false
  end

  def store_survey_data(power)
    path = File.expand_path(File.join(results_dir, @game.name))
    puts "Writing survey data to '#{path}'..."
    data = {:director_for_first_game => @game.director_mode, :power => power.name, :game_name => @game.name }
    File.open(path, 'wb') do |f|
      f.write Marshal.dump(data)
    end
    return data
  end

  def results_dir
    File.join(File.dirname(__FILE__), '..', 'results')
  end

  def survey_data(id)
    path = File.expand_path(File.join(results_dir, "survey#{id}"))
    puts "Reading survey data from '#{path}'..."
    data = nil
    File.open(path, 'rb') do |f|
      data = Marshal.load(f)
    end
    return data
  end

  def power_selected(power)
    puts "Selected power '#{power}'..."
    @player = Diplomacy::Human.new
    @power = power

    randomly_include_director
    store_survey_data(power)

    start_game

    survey_id_alert
  end

  # Pop up a dialog box requesting the user enter their survey ID number.
  def survey_id_alert
    id = @game.name.match(/survey(\d+)/)[-1]
    puts "Survey ID = #{id}"
    survey_id_alert = ConfirmDialog.new mainWindow, "Record Survey ID", %{
Please write down the following number on your survey and
click OK to proceed: #{id}
}
    survey_id_alert.execute
  end

  def start_game
    mainWindow.power_selected(@power)
    @power.player = @player
    @game.start
    mainWindow.game_started
    mainWindow.show(PLACEMENT_SCREEN)
  end

  def orders_submitted(orders)
    begin
      puts "Submitting orders for #{@game.turn}:"
      puts orders
      power = @game.turn.power(@power)
      power.submit_orders(orders)
      mainWindow.orders.text = ''
      mainWindow.orders.setFocus

    rescue Exception, Diplomacy::Error => e
      msg = [
        e.message,
        %{
A problem was encountered with your orders. Please examine and
re-submit them. The following are examples of valid orders:

HOLD ORDERS
  a war h (Army in Warsaw hold)
  f lon hold (Fleet in London hold)
  stp/nc h (Piece in St. Petersburg North Coast hold)

  This is the default order for movement turns.

MOVE ORDERS
  a war - sil (Army in Warsaw move to Silesia)
  ven-tri (Army in Venice move to Trieste)

  Armies cannot move across sea provinces.

  Fleets cannot move across landlocked provinces.

SUPPORT ORDERS
  These must accompany a move order:

  a war - sil (Army in Warsaw move to Silesia)
  a pru s a war - sil (Army in Prussia support Army in Warsaw move to Silesia)

  pie - mar (Piece in Piedmont move to Marseilles)
  lyo s pie - mar (Fleet in Gulf of Lyon support piece in Piedmont move to Marseilles)
  a spa s pie - mar (Army in Spain support piece in Piedmont move to Marseilles)

  A support order is only possible if the supporting piece can also move
  into the destination province (of the move order).

  A piece has a strength equal to 1 + number of successful supports.

  Support can be cut by an attack on the supporting piece.

CONVOY ORDERS
  These must accompany "chained" movement orders:

  a lon-nth-nor
  f nth c a lon-nor

  a lon-eng-mao-por
  f eng c a lon-por
  f mao c a lon-por

  (NOTE: You need to specify the full path of the move, however each
  contributing convoy need only specify the origin and destination.)

  A convoy can be dislodged, in which case the army does not move.

RETREAT ORDERS
  a war-ukr
  f mao-spa/nc

  A piece cannot retreat to occupied provinces, or provinces from
  which it was attacked (including those provinces providing support
  to the attack).

BUILD ORDERS
  build a vie
  build f bre
  build f stp/nc

  You may only build pieces in home centres.

  You may not build pieces of the wrong type in a province (e.g.
  "build f vie")

DISBAND ORDERS
  disband a boh

  This order, given during a retreat or adjustment turn, causes the
  specified piece to be disbanded.

  This is the default order for retreat turns.

WAIVE ORDERS
  waive

  This order abandons one of your builds. If you do not have enough
  space to build another unit (e.g. you have 3 builds and only 1 empty
  home centre), you may issue this order.

  This is the default order for adjustment turns.
}
      ]
      ErrorDialog.new(mainWindow, msg).execute
      return
    end

    begin
      @game.judge
      mainWindow.game_advanced(@game)
      puts "Successful!"
    rescue Diplomacy::Error => e
      d = ErrorDialog.new(mainWindow, e.message)
      d.execute
    end
  end
end
