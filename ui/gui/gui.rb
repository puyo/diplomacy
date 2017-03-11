$LOAD_PATH << File.dirname(__FILE__)

require 'fox16'

class Fox::FXWindow
  def pad=(val)
    padTop = val
    padBottom = val
    padLeft = val
    padRight = val
  end
  alias :setPad :pad=
end

class Fox::FXObject
  def makeIcon(name, subdir='icons')
    $LOAD_PATH.each do |dir|
      path = File.join(dir, subdir, name) + '.*'
      filenames = Dir.glob(path)
      next if filenames.size == 0
      filename = filenames.first # Use the first one.
      case filename
      when /\.png$/
        return Fox::FXPNGIcon.new(app, File.open(filename, "rb").read)
      when /\.jpg$/
        return Fox::FXJPGIcon.new(app, File.open(filename, "rb").read)
      when /\.gif$/
        return Fox::FXGIFIcon.new(app, File.open(filename, "rb").read)
      else
        puts 'Invalid icon file type: "' + filename.to_s + '"'
      end
    end
    puts 'Cound not find icon: ' + name
  end

  private
  STYLES = {
    :setBoxColor => :foreground,
    :setForeColor => :foreground,
    :setBackColor => :background,
    :setTextColor => :text,
    :setHiliteColor => :highlight,
    :setShadowColor => :shadow,
    :setBaseColor => :base,
    :setSelBackColor => :selected_background,
    :setSelTextColor => :selected_text,
    :setComboStyle => :combo,
    :setFrameStyle => :frame,
    :setDecorations => :decoration,
    :setPad => :padding,
    :setGroupBoxStyle => :groupbox,
    :setLayoutHints => :layout,
    :setRadioColor => :foreground,
  }
  public

  def setStyle(type=self.class)
    $stderr.puts "#{self.class}#setStyle(#{type})" if $DEBUG
    klasses = [type]
    while klasses[-1] != Fox::FXObject
      klasses << klasses[-1].superclass
    end
    set = {}
    STYLES.each do |method, style|
      if respond_to?(method) and not set[method]
        args = nil
        klasses.reverse.each do |klass|
          break if args = (GUI.style[klass][style])
        end
        if args ||= GUI.globalStyle[style]
#         puts "#{self.class}##{method}(#{args.map{|a|a.inspect}.join(', ')})"
          set[method] = true
          send(method, *args)
        end
      end
    end
  end
end


module GUI
  include Fox

  module SimpleStyle
    def initialize(*args)
      super(*args)
      setStyle
    end
  end

  # Constants

  LAYOUT_FILL_BOTH = LAYOUT_FILL_X | LAYOUT_FILL_Y
  LAYOUT_FIX_BOTH = LAYOUT_FIX_WIDTH | LAYOUT_FIX_HEIGHT

  # Signals

  SIGNAL_NONE = SEL_NONE
  SIGNAL_KEYPRESS = SEL_KEYPRESS
  SIGNAL_KEYRELEASE = SEL_KEYRELEASE
  SIGNAL_LEFTBUTTONPRESS = SEL_LEFTBUTTONPRESS
  SIGNAL_LEFTBUTTONRELEASE = SEL_LEFTBUTTONRELEASE
  SIGNAL_MIDDLEBUTTONPRESS = SEL_MIDDLEBUTTONPRESS
  SIGNAL_MIDDLEBUTTONRELEASE = SEL_MIDDLEBUTTONRELEASE
  SIGNAL_RIGHTBUTTONPRESS = SEL_RIGHTBUTTONPRESS
  SIGNAL_RIGHTBUTTONRELEASE = SEL_RIGHTBUTTONRELEASE
  SIGNAL_MOTION = SEL_MOTION
  SIGNAL_ENTER = SEL_ENTER
  SIGNAL_LEAVE = SEL_LEAVE
  SIGNAL_FOCUSIN = SEL_FOCUSIN
  SIGNAL_FOCUSOUT = SEL_FOCUSOUT
  SIGNAL_KEYMAP = SEL_KEYMAP
  SIGNAL_UNGRABBED = SEL_UNGRABBED
  SIGNAL_PAINT = SEL_PAINT
  SIGNAL_CREATE = SEL_CREATE
  SIGNAL_DESTROY = SEL_DESTROY
  SIGNAL_UNMAP = SEL_UNMAP
  SIGNAL_MAP = SEL_MAP
  SIGNAL_CONFIGURE = SEL_CONFIGURE
  SIGNAL_SELECTION_LOST = SEL_SELECTION_LOST
  SIGNAL_SELECTION_GAINED = SEL_SELECTION_GAINED
  SIGNAL_SELECTION_REQUEST = SEL_SELECTION_REQUEST
  SIGNAL_RAISED = SEL_RAISED
  SIGNAL_LOWERED = SEL_LOWERED
  SIGNAL_CLOSE = SEL_CLOSE
  SIGNAL_CLOSEALL = SEL_CLOSEALL
  SIGNAL_DELETE = SEL_DELETE
  SIGNAL_MINIMIZE = SEL_MINIMIZE
  SIGNAL_RESTORE = SEL_RESTORE
  SIGNAL_MAXIMIZE = SEL_MAXIMIZE
  SIGNAL_UPDATE = SEL_UPDATE
  SIGNAL_COMMAND = SEL_COMMAND
  SIGNAL_CLICKED = SEL_CLICKED
  SIGNAL_DOUBLECLICKED = SEL_DOUBLECLICKED
  SIGNAL_TRIPLECLICKED = SEL_TRIPLECLICKED
  SIGNAL_MOUSEWHEEL = SEL_MOUSEWHEEL
  SIGNAL_CHANGED = SEL_CHANGED
  SIGNAL_VERIFY = SEL_VERIFY
  SIGNAL_DESELECTED = SEL_DESELECTED
  SIGNAL_SELECTED = SEL_SELECTED
  SIGNAL_INSERTED = SEL_INSERTED
  SIGNAL_REPLACED = SEL_REPLACED
  SIGNAL_DELETED = SEL_DELETED
  SIGNAL_OPENED = SEL_OPENED
  SIGNAL_CLOSED = SEL_CLOSED
  SIGNAL_EXPANDED = SEL_EXPANDED
  SIGNAL_COLLAPSED = SEL_COLLAPSED
  SIGNAL_BEGINDRAG = SEL_BEGINDRAG
  SIGNAL_ENDDRAG = SEL_ENDDRAG
  SIGNAL_DRAGGED = SEL_DRAGGED
  SIGNAL_LASSOED = SEL_LASSOED
  SIGNAL_TIMEOUT = SEL_TIMEOUT
  SIGNAL_SIGNAL = SEL_SIGNAL
  SIGNAL_CLIPBOARD_LOST = SEL_CLIPBOARD_LOST
  SIGNAL_CLIPBOARD_GAINED = SEL_CLIPBOARD_GAINED
  SIGNAL_CLIPBOARD_REQUEST = SEL_CLIPBOARD_REQUEST
  SIGNAL_CHORE = SEL_CHORE
  SIGNAL_FOCUS_SELF = SEL_FOCUS_SELF
  SIGNAL_FOCUS_RIGHT = SEL_FOCUS_RIGHT
  SIGNAL_FOCUS_LEFT = SEL_FOCUS_LEFT
  SIGNAL_FOCUS_DOWN = SEL_FOCUS_DOWN
  SIGNAL_FOCUS_UP = SEL_FOCUS_UP
  SIGNAL_FOCUS_NEXT = SEL_FOCUS_NEXT
  SIGNAL_FOCUS_PREV = SEL_FOCUS_PREV
  SIGNAL_DND_ENTER = SEL_DND_ENTER
  SIGNAL_DND_LEAVE = SEL_DND_LEAVE
  SIGNAL_DND_DROP = SEL_DND_DROP
  SIGNAL_DND_MOTION = SEL_DND_MOTION
  SIGNAL_DND_REQUEST = SEL_DND_REQUEST
  SIGNAL_UNCHECK_OTHER = SEL_UNCHECK_OTHER
  SIGNAL_UNCHECK_RADIO = SEL_UNCHECK_RADIO
  SIGNAL_IO_READ = SEL_IO_READ
  SIGNAL_IO_WRITE = SEL_IO_WRITE
  SIGNAL_IO_EXCEPT = SEL_IO_EXCEPT
  SIGNAL_PICKED = SEL_PICKED
  SIGNAL_LAST = SEL_LAST

  # Class variables

  @nextSignal = SIGNAL_LAST
  @style = Hash.new{|h,k| h[k] = {} }
  @globalStyle = {}

  class << self
    attr_reader :style, :globalStyle

    def nextSignal
      val = @nextSignal
      @nextSignal += 1
      return val
    end
    
    def setGlobalStyle(key, *args)
      @globalStyle[key] = args
    end

    def setStyle(klass, key, *args)
      @style[klass][key] = args
    end

    def rgb(col)
      r = (col >> 16) & 0xFF
      g = (col >> 8) & 0xFF
      b = col & 0xFF
      ((b << 16) | (g << 8) | r)
    end

    def bgr(col)
      col
    end
  end

  # Colours

  BLACK = 0x000000
  BLUE = 0xFF0000
  GREEN = 0x00FF00
  RED = 0x0000FF
  WHITE = 0xFFFFFF
  GREY = 0x808080
  LIGHT_GREY = 0xbdbebd
  
  class App < FXApp
    TITLE = '<default title>'
    VENDOR = '<default vendor>'

    def initialize(title=TITLE, vendor=VENDOR)
      super(title, vendor)
      setStyle
    end

    def quit
      confirm = ConfirmDialog.new(self, 'Quit?', 'Are you sure you want to quit?')
      exit if confirm.execute
    end
  end
  class ArrowButton < FXArrowButton
    include SimpleStyle
  end
  class Button < FXButton
    include SimpleStyle
  end
  class CancelButton < Button
    def initialize(parent, label='&Cancel', target=parent)
      super(parent, label, nil, target, DialogBox::ID_CANCEL)
    end
  end
  class CheckButton < FXCheckButton
    include SimpleStyle
  end
  class ComboBox < FXComboBox
    include SimpleStyle
  end
  setStyle(ComboBox, :combo, Fox::COMBOBOX_INSERT_LAST)
  setStyle(ComboBox, :frame, Fox::FRAME_SUNKEN|Fox::FRAME_THICK)
  class Composite
    include SimpleStyle
  end
  class DialogBox < FXDialogBox
    include SimpleStyle
    def create
      super
      show(Fox::PLACEMENT_OWNER)
    end
    def execute
      result = super(Fox::PLACEMENT_OWNER)
      return result != 0
    end
  end
  class FileDialog < FXFileDialog
    include SimpleStyle
  end
  class GroupBox < FXGroupBox
    include SimpleStyle
  end
  class Frame < GroupBox
    include SimpleStyle
  end
  class HorizontalFrame < FXHorizontalFrame
    include SimpleStyle
  end
  class HorizontalSeparator < FXHorizontalSeparator
    include SimpleStyle
  end
  class Label < FXLabel
    include SimpleStyle
  end
  class List < FXList
    include SimpleStyle
  end
  class ListBox < FXListBox
    include SimpleStyle
  end
  class ListItem < FXListItem
    include SimpleStyle
  end
  class MainWindow < FXMainWindow
    def initialize(*args)
      super(*args)
      setStyle
      connect(SIGNAL_CLOSE) { app.quit }
    end
  end
  class Matrix < FXMatrix
    include SimpleStyle
  end
  class Menubar < FXMenubar
    include SimpleStyle
  end
  class MenuCommand < FXMenuCommand
    include SimpleStyle
    def connect(sig=SIGNAL_COMMAND)
      super(sig)
    end
  end
  class MenuPane < FXMenuPane
    include SimpleStyle
  end
  class MenuSeparator < FXMenuSeparator
    include SimpleStyle
  end
  class MenuTitle < FXMenuTitle
    include SimpleStyle
  end
  class OkayButton < Button
    def initialize(parent, label='&Okay', target=parent)
      super(parent, label, nil, target, DialogBox::ID_ACCEPT)
      setStyle
    end
  end
  class PNGImage < FXPNGImage
  end
  class RadioButton < FXRadioButton
    include SimpleStyle
  end
  class ScrollWindow < FXScrollWindow
    include SimpleStyle
    def setStyle
      super
      horizontalScrollbar.setStyle
      verticalScrollbar.setStyle
    end
  end
  class Statusbar < FXStatusbar
    include SimpleStyle
    def setStyle
      super
      getStatusline.setStyle
      getDragCorner.setStyle
    end
  end
  class Switcher < FXSwitcher
    include SimpleStyle
  end
  class Text < FXText
    include SimpleStyle
    def setStyle
      super
      verticalScrollbar.setStyle
      horizontalScrollbar.setStyle
    end
  end
  class TextField < FXTextField
    include SimpleStyle
  end
  class TreeItem < FXTreeItem
    include SimpleStyle
  end
  class TreeList < FXTreeList
    include SimpleStyle
  end
  class TreeListBox < FXTreeListBox
    include SimpleStyle
  end
  class VerticalFrame < FXVerticalFrame
    include SimpleStyle
  end

  # --- Custom Widgets ---------------

  class HorizontalButtonFrame < HorizontalFrame
    def initialize(*args)
      super(*args)
      setHSpacing(5)
      setLayoutHints(Fox::LAYOUT_RIGHT|Fox::LAYOUT_BOTTOM)
      setStyle
    end
  end

  class ConfirmDialog < DialogBox
    def initialize(parent, title='Confirm', text='Please confirm')
      super(parent, title)
      l = Label.new(self, text)
      s = HorizontalSeparator.new(self)
      f = HorizontalButtonFrame.new(self)
      f.setLayoutHints(Fox::LAYOUT_RIGHT)
      ok = OkayButton.new(f, '&Okay', self)
      ok.setDefault
      ok.setFocus
#     cancel = CancelButton.new(f, '&Cancel', self)
    end
  end

  class ErrorDialog < DialogBox
    def initialize(parent, text=nil)
      super(parent, 'Error')
      setWidth(600)
      setHeight(400)
      setLayoutHints(LAYOUT_FIX_BOTH)
      case text
      when Array
        text = text.join("\n")
      end
      puts text
      v = VerticalFrame.new(self)
      v.setLayoutHints(LAYOUT_FILL_BOTH)
      if text
        t = Text.new(v, nil, 0, Fox::TEXT_WORDWRAP|Fox::TEXT_READONLY)
        t.setLayoutHints(LAYOUT_FILL_BOTH)
        t.setText(text)
      end
      HorizontalSeparator.new(v)
      f = HorizontalButtonFrame.new(v)
      #f.setLayoutHints(LAYOUT_RIGHT)
      ok = Button.new(f, '&Okay', nil, self, ID_ACCEPT)
      ok.setDefault
      ok.setFocus
    end
  end

  class ButtonTray < Composite
    attr :frame
    def initialize(parent, backColour=0x888888)
      super(parent)
      @backColour = backColour

      @scrollWindow = ScrollWindow.new(parent)
      @scrollWindow.setLayoutHints(LAYOUT_FILL_BOTH)

      @frame = VerticalFrame.new(@scrollWindow)
      @frame.setFrameStyle(FRAME_SUNKEN | FRAME_THICK)
      @frame.setBackColor(backColour)
      @frame.setLayoutHints(LAYOUT_FILL_BOTH)
    end
    def method_missing(m, *args)
      @scrollWindow.send(m, *args)
    end
  end

  class TrayButton < Button
    def initialize(parent, caption, icon, desc='')
      if parent.is_a? ButtonTray
        parent = parent.frame
      end
      f = HorizontalFrame.new(parent)
      f.setLayoutHints(LAYOUT_FILL_X)
      f.setBackColor(parent.getBackColor)
      b = Button.new(f, '', icon)
      b.setPad(-2)
      b.setBackColor(parent.getBackColor/2)
      b.setTextColor(0x000000)
      b.command { |*args|
        @callback.call(*args) if @callback
      }

      l = Label.new(f, caption)
      l.setLayoutHints(LAYOUT_RIGHT|LAYOUT_FILL_X)
      l.setBackColor(parent.getBackColor)
      l.setJustify(JUSTIFY_RIGHT)

      HorizontalSeparator.new(parent)
    end
    def command(&block)
      @callback = block
    end
  end
end

