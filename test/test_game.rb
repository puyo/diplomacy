require 'test/unit'
require_relative '../lib/diplomacy/game'
require_relative '../lib/diplomacy/util'

class GameTest < Test::Unit::TestCase
  include Diplomacy

  def reset
    @game = Game.new(name: 'test')
    @game.start(false, false)
  end

  def setup
    reset
    Util.log '----------------------------------------------------------'
    Util.log '----------------------------------------------------------'
    Util.log '----------------------------------------------------------'
    Util.log method_name
    Util.log '----------------------------------------------------------'
    Util.log '----------------------------------------------------------'
    Util.log '----------------------------------------------------------'
  end

  attr_reader :game

  def austria; turn.power(map.power_definition('a')) end
  def england; turn.power(map.power_definition('e')) end
  def france; turn.power(map.power_definition('f')) end
  def germany; turn.power(map.power_definition('g')) end
  def italy; turn.power(map.power_definition('i')) end
  def russia; turn.power(map.power_definition('r')) end
  def turkey; turn.power(map.power_definition('t')) end

  def map
    @game.map
  end

  def turn
    @game.turn
  end

  def previous_turn
    @game.previous_turn
  end

  def history
    game.turns.map{|t| t.inspect}.join("\n-----\n")
  end

  def assert_order(loc, owner, klass, msg)
    area = map.parse_area(loc)
    piece = turn.piece(area)
    assert piece && piece.owner == owner && piece.order.class == klass, "#{msg}\n#{history}"
  end

  def assert_result(loc, owner, results, msg)
    assert p = turn.piece(loc) && p.owner == owner && p.order.results == results, "#{msg}\n#{history}"
  end

  # This isn't perfect... how should it be done? hmm...
  def assert_moved(piece, orig, dest)
    oldpiece = previous_turn.piece(orig, piece.type)
    newpiece = turn.piece(dest, piece.type)
    assert oldpiece == newpiece, "#{oldpiece} did not move to #{dest}\n#{history}"
    reppiece = turn.piece(orig, piece.type)
    assert reppiece.nil? || (reppiece != oldpiece), "#{oldpiece} duplicated in #{dest}\n#{history}"
  end

  def assert_stayed(piece)
    oldpiece = piece
    newpiece = turn.piece(piece.area)
    assert oldpiece == newpiece, "#{oldpiece.inspect} should not be #{newpiece.inspect}\n#{history}"
  end

  def assert_bounced(piece)
    assert_stayed(piece)
    assert piece.bounced?, "#{piece} did not bounce\n#{history}"
  end

  def assert_dislodged(piece)
    assert piece.dislodged?, "#{piece} was not dislodged\n#{history}"
  end

  def assert_cut(piece)
    assert piece.cut?, "#{piece} support was not cut\n#{history}"
  end

  def assert_failed(piece)
    assert (piece.order and !piece.order.successful?), "#{piece} was successful\n#{history}"
  end

  # orders submission
  def test_orders
    england.submit_orders %{
      F Edi - Nth
      A Lvp H
      F Lon-Nth-Nor
    }
    assert_order "f edi", england, MoveOrder, "Order not received"
    assert_order "a lvp", england, HoldOrder, "Order not received"
    assert_order "f lon", england, ConvoyedMoveOrder, "Order not received"
  end

  # army movement
  def test_1
    destinations = "bur pic bre gas".split
    destinations.each do |dest|
      reset
      turn.clear_pieces
      a = france.make_piece("a par")
      france.submit_orders("a par - #{dest}")
      game.judge
      assert_moved a, "par", dest
    end
  end

  # fleet movement
  def test_2
    destinations = "mao iri wal lon nth bel pic bre".split
    destinations.each do |dest|
      reset
      turn.clear_pieces
      f = england.make_piece("f eng")
      england.submit_orders("f eng - #{dest}")
      game.judge
      assert_moved f, "eng", dest
    end
  end

  # assert some impossible moves fail
  def test_3
    okdest = "tus nap".split
    nodest = "ven apu".split
    okdest.each do |dest|
      reset
      turn.clear_pieces
      f = italy.make_piece("f rom")
      italy.submit_orders("f rom-#{dest}")
      game.judge
      assert_moved f, "rom", dest
    end
    nodest.each do |dest|
      reset
      turn.clear_pieces
      f = italy.make_piece("f rom")
      italy.submit_orders("f rom-#{dest}")
      game.judge
      assert_stayed f
    end
  end

  # two armies moving into the same province
  def test_4
    turn.clear_pieces
    g = germany.make_piece("a ber")
    r = russia.make_piece("a war")
    germany.submit_orders("a ber-sil")
    russia.submit_orders("a war-sil")
    game.judge
    assert_bounced g
    assert_bounced r
  end

  # a congo line of armies with the head stopped
  def test_5
    turn.clear_pieces
    ga = germany.make_piece("a ber")
    gf = germany.make_piece("f kie")
    russia.make_piece("a pru")
    germany.submit_orders %{
      a ber-pru
      f kie-ber
    }
    russia.submit_orders %{
      a pru h
    }
    game.judge
    assert_bounced ga
    assert_bounced gf
  end

  # two armies moving into each other's provinces (swapping)
  def test_6
    turn.clear_pieces
    f = germany.make_piece("f ber")
    a = germany.make_piece("a pru")
    germany.submit_orders %{
      f ber-pru
      a pru-ber
    }
    game.judge
    assert_bounced f
    assert_bounced a
  end

  # three-way rotate
  def test_7
    turn.clear_pieces
    ea = england.make_piece("a hol")
    ef = england.make_piece("f bel")
    ff = france.make_piece("f nth")
    england.submit_orders %{
      a hol-bel
      f bel-nth
    }
    france.submit_orders %{
      f nth-hol
    }
    game.judge
    assert_moved ea, "hol", "bel"
    assert_moved ef, "bel", "nth"
    assert_moved ff, "nth", "hol"
  end

  # simple support
  def test_8
    turn.clear_pieces
    ga = germany.make_piece("a bur")
    fa1 = france.make_piece("a gas")
    fa2 = france.make_piece("a mar")
    germany.submit_orders %{
      a bur h
    }
    france.submit_orders %{
      a gas s a mar-bur
      a mar-bur
    }
    game.judge
    assert_stayed fa1
    assert_moved fa2, "mar", "bur"
    assert_dislodged ga
  end

  # a support with help from a fleet
  def test_9
    turn.clear_pieces
    ga = germany.make_piece("a sil")
    gf = germany.make_piece("f bal")
    ra = russia.make_piece("a pru")
    germany.submit_orders %{
      a sil-pru
      f bal s a sil-pru
    }
    russia.submit_orders %{
      a pru hold
    }
    game.judge
    assert_moved ga, "sil", "pru"
    assert_stayed gf
    assert_dislodged ra
  end

  # a supported move bounce
  def test_10
    turn.clear_pieces
    if1 = italy.make_piece("f rom")
    if2 = italy.make_piece("f nap")
    ff1 = france.make_piece("f lyo")
    ff2 = france.make_piece("f wes")
    france.submit_orders %{
      f lyo-tys
      f wes s f lyo-tys
    }
    italy.submit_orders %{
      f nap-tys
      f rom s f nap-tys
    }
    game.judge
    assert_stayed if1
    assert_stayed if2
    assert_stayed ff1
    assert_stayed ff2
  end

  # a supported hold bounce
  def test_11
    turn.clear_pieces
    if1 = italy.make_piece("f rom")
    if2 = italy.make_piece("f tys")
    ff1 = france.make_piece("f lyo")
    ff2 = france.make_piece("f wes")
    france.submit_orders %{
      f lyo-tys
      f wes s f lyo-tys
    }
    italy.submit_orders %{
      f tys hold
      f rom s f tys h
    }
    game.judge
    assert_stayed if1
    assert_stayed if2
    assert_stayed ff1
    assert_stayed ff2
  end

  def test_12
    turn.clear_pieces
    aa1 = austria.make_piece("a boh")
    aa2 = austria.make_piece("a tyl")
    ga1 = germany.make_piece("a mun")
    ga2 = germany.make_piece("a ber")
    ra1 = russia.make_piece("a war")
    ra2 = russia.make_piece("a pru")
    austria.submit_orders %{
      a boh-mun
      a tyl s a boh-mun
    }
    germany.submit_orders %{
      a mun-sil
      a ber s a mun-sil
    }
    russia.submit_orders %{
      a war-sil
      a pru s a war-sil
    }
    game.judge
    assert_moved aa1, "boh", "mun"
    assert_stayed aa2
    assert_dislodged ga1
    assert_stayed ga2
    assert_bounced ra1
    assert_stayed ra2
  end

  def test_13
    turn.clear_pieces
    ta = turkey.make_piece("a bul")
    ra1 = russia.make_piece("a rum")
    ra2 = russia.make_piece("a sev")
    ra3 = russia.make_piece("a ser")
    turkey.submit_orders %{
      a bul-rum
    }
    russia.submit_orders %{
      a rum-bul
      a ser s a rum-bul
      a sev-rum
    }
    game.judge
    assert_dislodged ta
    assert_moved ra1, "rum", "bul"
    assert_moved ra2, "sev", "rum"
  end

  def test_14
    turn.clear_pieces
    ta = turkey.make_piece "a bul"
    tf = turkey.make_piece "f bla"
    ra1 = russia.make_piece "a rum"
    ra2 = russia.make_piece "a gre"
    ra3 = russia.make_piece "a ser"
    ra4 = russia.make_piece "a sev"
    turkey.submit_orders %{
      a bul-rum
      f bla s a bul-rum
    }
    russia.submit_orders %{
      a rum-bul
      a gre s a rum-bul
      a ser s a rum-bul
      a sev-rum
    }
    game.judge
    assert_dislodged ta
    assert_moved ra1, "rum", "bul"
    assert_moved ra4, "sev", "rum"
  end

  # simple cut support
  def test_15
    turn.clear_pieces
    ga1 = germany.make_piece "a pru"
    ga2 = germany.make_piece "a sil"
    ra1 = russia.make_piece "a war"
    ra2 = russia.make_piece "a boh"
    germany.submit_orders %{
      a pru-war
      a sil s a pru-war
    }
    russia.submit_orders %{
      a war hold
      a boh-sil
    }
    game.judge
    assert_bounced ga1
    assert_cut ga2
    assert_stayed ra1
    assert_bounced ra2
  end

  # Attacking a support into your own province does not cut it
  def test_16
    turn.clear_pieces
    ga1 = germany.make_piece "a pru"
    ga2 = germany.make_piece "a sil"
    ra = russia.make_piece "a war"
    germany.submit_orders %{
      a pru-war
      a sil s a pru-war
    }
    russia.submit_orders %{
      a war-sil
    }
    game.judge
    assert_dislodged ra
    assert_moved ga1, "pru", "war"
  end

  def test_17
    turn.clear_pieces
    ga = germany.make_piece "a sil"
    gf = germany.make_piece "f ber"
    ra1 = russia.make_piece "a pru"
    ra2 = russia.make_piece "a war"
    rf = russia.make_piece "f bal"
    germany.submit_orders %{
      f ber-pru
      a sil s f ber-pru
    }
    russia.submit_orders %{
      a pru-sil
      a war s a pru-sil
      f bal-pru
    }
    game.judge
    assert_dislodged ga
    assert_bounced gf
    assert_bounced rf
    assert_moved ra1, "pru", "sil"
  end

  def test_18
    turn.clear_pieces
    ga1 = germany.make_piece "a ber"
    ga2 = germany.make_piece "a mun"
    ra1 = russia.make_piece "a pru"
    ra2 = russia.make_piece "a sil"
    ra3 = russia.make_piece "a boh"
    ra4 = russia.make_piece "a tyl"
    germany.submit_orders %{
      a ber hold
      a mun-sil
    }
    russia.submit_orders %{
      a pru-ber
      a sil s a pru-ber
      a boh-mun
      a tyl s a boh-mun
    }
    game.judge
    assert_dislodged ga2
    assert_bounced ra1
    assert_cut ra2
    assert_stayed ga1
    assert_moved ra3, "boh", "mun"
  end

  # simple convoy
  def test_19
    turn.clear_pieces
    ea = england.make_piece "a lon"
    ef = england.make_piece "f nth"
    england.submit_orders %{
      a lon-nth-nor
      f nth c a lon-nor
    }
    game.judge
    assert_moved ea, "lon", "nor"
  end

  # long convoy
  def test_20
    turn.clear_pieces
    ea = england.make_piece "a lon"
    ef1 = england.make_piece "f eng"
    ef2 = england.make_piece "f mao"
    ff = france.make_piece "f wes"
    england.submit_orders %{
      a lon-eng-mao-wes-tun
      f eng c a lon-tun
      f mao c a lon-tun
    }
    france.submit_orders %{
      f wes c a lon-tun
    }
    game.judge
    assert_moved ea, "lon", "tun"
  end

  # convoy link dislodged
  def test_21
    turn.clear_pieces
    if1 = italy.make_piece "f ion"
    if2 = italy.make_piece "f tun"
    fa = france.make_piece "a spa"
    ff1 = france.make_piece "f lyo"
    ff2 = france.make_piece "f tys"
    italy.submit_orders %{
      f ion-tys
      f tun s f ion-tys
    }
    france.submit_orders %{
      a spa-lyo-tys-nap
      f lyo c a spa-nap
      f tys c a spa-nap
    }
    game.judge
    assert_stayed fa
    assert_moved if1, "ion", "tys"
    assert_dislodged ff2
  end

  # self dislodgement disallowed
  def test_22
    turn.clear_pieces
    fa1 = france.make_piece "a par"
    fa2 = france.make_piece "a mar"
    fa3 = france.make_piece "a bur"
    france.submit_orders %{
      a par-bur
      a mar s a par-bur
      a bur hold
    }
    game.judge
    assert_stayed fa1
    assert_stayed fa3
  end

  # self dislodgement supported by others still disallowed
  def test_23
    turn.clear_pieces
    fa1 = france.make_piece "a par"
    fa2 = france.make_piece "a bur"
    ga = germany.make_piece "a ruh"
    ia = italy.make_piece "a mar"
    france.submit_orders %{
      a par-bur
      a bur-mar
    }
    germany.submit_orders %{
      a ruh s a par-bur
    }
    italy.submit_orders %{
      a mar-bur
    }
    game.judge
    assert_stayed fa1
    assert_stayed fa2
    assert_stayed ia
  end

  # support for self-dislodgement disallowed
  def test_24
    turn.clear_pieces
    ga1 = germany.make_piece "a ruh"
    ga2 = germany.make_piece "a mun"
    fa1 = france.make_piece "a par"
    fa2 = france.make_piece "a bur"
    france.submit_orders %{
      a par s a ruh-bur
      a bur hold
    }
    germany.submit_orders %{
      a ruh-bur
      a mun hold
    }
    game.judge
    assert_stayed ga1
  end

  # support for self-dislodgement after a bounce disallowed
  def test_25
    turn.clear_pieces
    ga1 = germany.make_piece "a mun"
    ga2 = germany.make_piece "a ruh"
    ga3 = germany.make_piece "a sil"
    aa1 = austria.make_piece "a tyl"
    aa2 = austria.make_piece "a boh"
    germany.submit_orders %{
      a mun-tyl
      a ruh-mun
      a sil-mun
    }
    austria.submit_orders %{
      a tyl-mun
      a boh s a sil-mun
    }
    game.judge
    assert_bounced ga1
    assert_bounced ga2
    assert_bounced ga3
    assert_bounced aa1
  end

  # all sorts of weird stuff...
  def test_26
    turn.clear_pieces
    ef1 = england.make_piece "f den"
    ef2 = england.make_piece "f nth"
    ef3 = england.make_piece "f hel"
    ra = russia.make_piece "a ber"
    rf1 = russia.make_piece "f ska"
    rf2 = russia.make_piece "f bal"
    england.submit_orders %{
      f den-kie
      f nth-den
      f hel s f nth-den
    }
    russia.submit_orders %{
      a ber-kie
      f ska-den
      f bal s f ska-den
    }
    game.judge
    assert_bounced ef1
    assert_bounced ef2
    assert_bounced ra
    assert_bounced rf1
  end

  # unexpected support
  def test_27
    turn.clear_pieces
    aa1 = austria.make_piece "a ser"
    aa2 = austria.make_piece "a vie"
    ra = russia.make_piece "a gal"
    austria.submit_orders %{
      a ser-bud
      a vie-bud
    }
    russia.submit_orders %{
      a gal s a ser-bud
    }
    game.judge
    assert_moved aa1, "ser", "bud"
    assert_bounced aa2
  end

  # trading places via convoys
  def test_28
    turn.clear_pieces
    ea = england.make_piece "a lon"
    ef = england.make_piece "f nth"
    fa = france.make_piece "a bel"
    ff = france.make_piece "f eng"
    england.submit_orders %{
      a lon-nth-bel
      f nth c a lon-bel
    }
    france.submit_orders %{
      a bel-eng-lon
      f eng c a bel-lon
    }
    game.judge
    assert_moved ea, "lon", "bel"
    assert_moved fa, "bel", "lon"
  end

  # alternate convoy routes if first route cut
  # won't work as we must specify route
  #	def test_tricky_29
  #		assert false, "Not supported (yet?)"
  #	end

  # the convoy paradox
  def test_30
    turn.clear_pieces
    fa = france.make_piece "a tun"
    ff = france.make_piece "f tys"
    if1 = italy.make_piece "f ion"
    if2 = italy.make_piece "f nap"
    france.submit_orders %{
      a tun-tys-nap
      f tys c a tun-nap
    }
    italy.submit_orders %{
      f ion-tys
      f nap s f ion-tys
    }
    game.judge
    assert_moved if1, "ion", "tys"
    assert_dislodged ff
    assert_stayed fa
  end

  # avoiding problem 30 with an alternate route
  #	def test_tricky_31
  #		assert false, "Not supported (yet?)"
  #	end

  # supporting a convoyed landing (diff. to rules)
  def test_32a
    turn.clear_pieces
    fa1 = france.make_piece "a tun"
    fa2 = france.make_piece "a apu"
    ff1 = france.make_piece "f tys"
    ff2 = france.make_piece "f ion"
    if1 = italy.make_piece "f rom"
    if2 = italy.make_piece "f nap"
    france.submit_orders %{
      a tun-ion-nap
      f tys hold
      f ion c a tun-nap
      a apu s a tun-ion-nap
    }
    italy.submit_orders %{
      f rom-tys
      f nap s f rom-tys
    }
    game.judge
    assert_moved fa1, "tun", "nap"
    assert_bounced if1
    assert_cut if2
    assert_dislodged if2
  end

  # moving in a chain
  def test_g1
    g1 = turn.piece "f kie"
    g2 = turn.piece "a mun"
    g3 = turn.piece "a ber"
    germany.submit_orders %{
      F KIE - HOL
      A MUN - BER
      A BER - KIE
    }
    game.judge
    assert_moved g1, "kie", "hol"
    assert_moved g2, "mun", "ber"
    assert_moved g3, "ber", "kie"
  end

  # retreats
  def test_g2
    turn.clear_pieces
    ga1 = germany.make_piece "a mun"
    ga2 = germany.make_piece "a boh"
    ga3 = germany.make_piece "a pie"
    ga4 = germany.make_piece "a ven"
    ga5 = germany.make_piece "f tri"
    ga6 = germany.make_piece "a vie"
    aa1 = austria.make_piece "a tyl"
    germany.submit_orders %{
      A MUN - TYL
      A BOH S A MUN - TYL
    }
    game.judge
    assert_moved ga1, "mun", "tyl"
    aa1b = turn.piece_dislodged("a tyl")
    assert aa1b.retreats.empty?
  end

  # supporting support orders
  def test_g3
    turn.clear_pieces
    ga1 = germany.make_piece "a mun"
    ga2 = germany.make_piece "a boh"
    aa1 = austria.make_piece "a tyl"
    germany.submit_orders %{
      a mun s a boh
      a boh s a mun
    }
    austria.submit_orders %{
      a tyl-mun
    }
    game.judge
    assert_bounced aa1
    assert_stayed ga1
    assert_stayed ga2
  end

  # retreating to the same province
  def test_g4
    turn.clear_pieces
    ga1 = germany.make_piece "a mun"
    ga2 = germany.make_piece "a boh"
    ga3 = germany.make_piece "a vie"
    aa1 = austria.make_piece "a tyl"
    aa2 = austria.make_piece "a bud"
    aa2 = austria.make_piece "a gal"
    germany.submit_orders %{
      a mun-tyl
      a boh s a mun-tyl
      a vie h
    }
    austria.submit_orders %{
      a tyl h
      a bud-vie
      a gal s a bud-vie
    }
    game.judge
    assert_dislodged aa1
    assert_dislodged ga3
    germany.submit_orders %{
      a vie - tri
    }
    austria.submit_orders %{
      a tyl - tri
    }
    game.judge
    assert_failed aa1
    assert_failed ga3
  end
end
