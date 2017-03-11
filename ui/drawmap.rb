# Extensions to the Diplomacy model used to represent it.

require_relative '../lib/diplomacy/game'
require_relative '../lib/diplomacy/order'
require_relative '../lib/diplomacy/moveorder'
require_relative '../lib/diplomacy/supportorder'
require 'GD'

class Diplomacy::Province
  attr_accessor :painted
end

class Diplomacy::Game

  def turn_images_path() File.join(File.dirname(__FILE__), '..', 'turnmaps') end

  def turn_image_path(turn=current_turn)
    File.join(turn_images_path, "#{id(turn)}.png")
  end

  def supply_icon_path
    File.join(map.supply_icons_path, "#{map.id}.png")
  end

  def piece_icon_path(type)
    File.join(map.piece_icons_path, "#{map.id}-#{type}.png")
  end

  def paint_provinces(turn, result)
    map.provinces.each{|p| p.painted = false }

    map.provinces.each do |province|
      turn.powers.each do |power|
        if power.owns?(province)
          province_col = power.definition.province_colour
          resource_col = power.definition.resource_colour
          if supply = province.supply
            colindex = result.colorResolve(province_col.hex)
          else
            colindex = result.colorResolve((province_col*1.3).hex)
          end
          province.paint_coordinates.each do |x, y|
            result.fill(x, y, colindex)
          end
          province.painted = true
        end
      end
    end

    map.provinces.each do |province|
      if not province.painted
        power_def = province.start_owner
        province_col = power_def.province_colour
        resource_col = power_def.resource_colour
        if supply = province.supply
          colindex = result.colorResolve(province_col.hex)
        else
          colindex = result.colorResolve((province_col*1.3).hex)
        end
        province.paint_coordinates.each do |x, y|
          result.fill(x, y, colindex)
        end
        province.painted = true
      end
    end

  end

  def paint_arrow(result, x0, y0, x1, y1, colour)
    brush = GD::Image.new(2,2)
    brush.filledRectangle(0,0,2,2,brush.colorAllocate(colour.hex))
    result.setBrush(brush)

    dx = x1-x0
    dy = y1-y0
    x1 = x0
    x1 += (dx/dx.abs)*(dx.abs-3) if dx != 0
    y1 = y0
    y1 += (dy/dy.abs)*(dy.abs-3) if dy != 0

    result.line(x0, y0, x1, y1, GD::Brushed)
    arrowwidth = 40
    arrowheight = 50
    arrowscale = 0.2
    arrowhead = GD::Polygon.new
    arrowhead.addPt(0, 0)
    arrowhead.addPt(arrowwidth/2, arrowheight)
    arrowhead.addPt(-arrowwidth/2, arrowheight)
    arrowhead.addPt(0, 0)

    angle = Math.atan2(dy, dx)
    angle += Math::PI/2
    c = Math.cos(angle)
    s = Math.sin(angle)
    arrowhead.transform(c,s,-s,c,0,0)
    arrowhead.scale(arrowscale, arrowscale)
    arrowhead.offset(x1,y1)

    result.filledPolygon(arrowhead, result.colorResolve(colour.hex))

    brush.destroy
  end

  def paint_support_move(result, x0, y0, x1, y1, colour)
    brush = GD::Image.new(2,2)
    brush.filledRectangle(0,0,2,2,brush.colorAllocate(colour.hex))
    result.setBrush(brush)

    result.line(x0, y0, x1, y1, GD::Brushed)
    result.arc(x1, y1, 5, 5, 0, 360, GD::Brushed)

    brush.destroy
  end

  def paint_support_piece(result, x0, y0, x1, y1, colour)
    brush = GD::Image.new(2,2)
    brush.filledRectangle(0,0,2,2,brush.colorAllocate(colour.hex))
    result.setBrush(brush)

    dx = x1-x0
    dy = y1-y0
    x1 = x0
    x1 += (dx/dx.abs)*(dx.abs-3) if dx != 0
    y1 = y0
    y1 += (dy/dy.abs)*(dy.abs-3) if dy != 0

    result.line(x0, y0, x1, y1, GD::Brushed)
    result.arc(x1, y1, 5, 5, 0, 360, GD::Brushed)

    brush.destroy
  end

  def paint_arrows(turn, result, orders=turn.orders)
    move_col = RGB.new("#ff0000")
    support_col = RGB.new("#00ff00")
    convoy_col = RGB.new("#0000ff")
    
    move_orders = orders.find_all{|o| o.is_a?(Diplomacy::MoveOrder) }
    other_orders = orders.find_all{|o| o.is_a?(Diplomacy::PieceOrder) } - move_orders
    move_orders.each do |order|
      success_scale = order.successful? ? 1.0 : 0.7
      x0, y0 = order.piece.area.coordinates[0]
      x1, y1 = order.destination.coordinates[0]
      paint_arrow(result, x0, y0, x1, y1, move_col * success_scale)
    end

    other_orders.each do |order|
      success_scale = order.successful? ? 1.0 : 0.7
      x0, y0 = order.piece.area.coordinates[0]
      case order
      when Diplomacy::SupportOrder
        supported_order = orders.find{|o| o.piece == order.supported_piece }
        supported_from = order.supported_piece.area
        supported_to = supported_order.respond_to?(:destination) ? supported_order.destination : supported_from

        x2, y2 = supported_from.coordinates.first
        x3, y3 = supported_to.coordinates.first
        
        x1 = (x2 + x3)/2
        y1 = (y2 + y3)/2
        if supported_order.is_a?(Diplomacy::MoveOrder)
          paint_support_move(result, x0, y0, x1, y1, support_col * success_scale)
        else
          paint_support_piece(result, x0, y0, x1, y1, support_col * success_scale)
        end
      when Diplomacy::ConvoyOrder
        x2, y2 = order.piece_convoyed.area.coordinates.first
        x3, y3 = order.piece_destination.coordinates.first
        x1 = (x2 + x3)/2
        y1 = (y2 + y3)/2
        paint_support_move(result, x0, y0, x1, y1, convoy_col * success_scale)
      end
    end
  end

  def paint_pieces(turn, result, piece_icons)
    turn.powers.each do |power|
      resource_col = power.definition.resource_colour
      power.pieces.each do |piece|
        x, y = piece.area.coordinates[0]
        icon = piece_icons[piece.type]
        pw, ph = icon.width, icon.height
        icon.copy(result, x-pw/2, y-ph/2, 0, 0, pw, ph)
        result.fill(x, y, result.colorResolve(resource_col.hex))
      end
    end
  end

  def paint_labels(turn, result, piece_icons)
    black = result.colorResolve("#000000")
    map.provinces.each do |province|
      smallfont = GD::Font::SmallFont
      largefont = GD::Font::MediumFont
      piece = turn.piece(province)
      labelled = false
      map.types.each do |type|
        province.areas(type).each do |area|
          if area.id == ''
            break if labelled
            label = province.id
            font = largefont
          else
            font = smallfont
            label = area.id
          end
          if piece and piece.area == area
            label_coords = piece.area.coordinates[0].dup
            icon = piece_icons[piece.type]
            pw, ph = icon.width, icon.height
            label_coords[1] += ph/2 + 1
          else
            label_coords = area.coordinates[0].dup
            label_coords[1] -= font.height/2
          end
          x, y = *label_coords
          x -= label.size*font.width/2
          result.string(font, x, y, label, black)
          labelled = true
        end
      end
    end
  end

  def reoutput_turn_image(turn=current_turn)
    outpath = turn_image_path(turn)
    File.delete(outpath) if File.exist?(outpath)
    output_turn_image(turn)
  end

  def output_turn_image(turn=current_turn)
    outpath = turn_image_path(turn)
    return if File.exist?(outpath)

    result = loadPNG(map.base_path)
    supply_icon = loadPNG(supply_icon_path)
    piece_icons = {}
    map.types.each{|type| piece_icons[type] = loadPNG(piece_icon_path(type)) }

    paint_provinces(turn, result)
    paint_arrows(turn, result) if turn != current_turn and turn.is_a?(Diplomacy::MovementTurn)
    paint_pieces(turn, result, piece_icons)
    paint_labels(turn, result, piece_icons)

    Dir.mkdir(turn_images_path) unless FileTest.directory?(turn_images_path)
    savePNG(result, outpath)
    result.destroy
  end

  private

  def loadPNG(path)
    File.open(path, 'rb') do |f|
      Util.log "Reading '#{path}'..."
      return GD::Image.newFromPng(f)
    end
  end

  def savePNG(image, path)
    File.open(path, "wb") do |f|
      Util.log "Writing '#{path}'..."
      image.png(f)
    end
  end
end
