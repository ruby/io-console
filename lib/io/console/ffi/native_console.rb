# Load appropriate native bits for BSD or Linux
case RbConfig::CONFIG['host_os'].downcase
when /darwin|openbsd|freebsd|netbsd/
  require_relative 'bsd_console'
when /linux/
  require_relative 'linux_console'
else
  raise LoadError.new("no native io/console support")
end

# Common logic that uses native calls for console
class IO
  def ttymode
    termios = LibC::Termios.new
    if LibC.tcgetattr(self.fileno, termios) != 0
      raise SystemCallError.new(path, FFI.errno)
    end

    if block_given?
      yield tmp = termios.dup
      if LibC.tcsetattr(self.fileno, LibC::TCSANOW, tmp) != 0
        raise SystemCallError.new(path, FFI.errno)
      end
    end
    termios
  end
  private :ttymode

  def ttymode_yield(block, **opts, &setup)
    begin
      orig_termios = ttymode { |t| setup.call(t, **opts) }
      block.call(self)
    ensure
      if orig_termios && LibC.tcsetattr(self.fileno, LibC::TCSANOW, orig_termios) != 0
        raise SystemCallError.new(path, FFI.errno)
      end
    end
  end
  private :ttymode_yield

  TTY_RAW = Proc.new do |t, min: 1, time: nil, intr: nil|
    LibC.cfmakeraw(t)
    t[:c_lflag] &= ~(LibC::ECHOE|LibC::ECHOK)
    if min >= 0
      t[:c_cc][LibC::VMIN] = min
    end
    t[:c_cc][LibC::VTIME] = (time&.to_i || 0) * 10
    if intr
      t[:c_iflag] |= LibC::BRKINT
      t[:c_lflag] |= LibC::ISIG
      t[:c_oflag] |= LibC::OPOST
    end
  end

  def raw(*, **kwargs, &block)
    ttymode_yield(block, **kwargs, &TTY_RAW)
  end

  def raw!(*)
    ttymode(&TTY_RAW)
  end

  TTY_COOKED = Proc.new do |t|
    t[:c_iflag] |= (LibC::BRKINT|LibC::ISTRIP|LibC::ICRNL|LibC::IXON)
    t[:c_oflag] |= LibC::OPOST
    t[:c_lflag] |= (LibC::ECHO|LibC::ECHOE|LibC::ECHOK|LibC::ECHONL|LibC::ICANON|LibC::ISIG|LibC::IEXTEN)
  end

  def cooked(*, &block)
    ttymode_yield(block, &TTY_COOKED)
  end

  def cooked!(*)
    ttymode(&TTY_COOKED)
  end

  TTY_ECHO = LibC::ECHO | LibC::ECHOE | LibC::ECHOK | LibC::ECHONL
  def echo=(echo)
    ttymode do |t|
      if echo
        t[:c_lflag] |= TTY_ECHO
      else
        t[:c_lflag] &= ~TTY_ECHO
      end
    end
  end

  def echo?
    (ttymode[:c_lflag] & (LibC::ECHO | LibC::ECHONL)) != 0
  end

  def noecho(&block)
    ttymode_yield(block) { |t| t[:c_lflag] &= ~(TTY_ECHO) }
  end

  def winsize
    ws = LibC::Winsize.new
    if LibC.ioctl(self.fileno, LibC::TIOCGWINSZ, :pointer, ws.pointer) != 0
      raise SystemCallError.new("ioctl(TIOCGWINSZ)", FFI.errno)
    end
    [ ws[:ws_row], ws[:ws_col] ]
  end

  def winsize=(size)
    size = size.to_ary unless size.kind_of?(Array)
    sizelen = size.size

    if sizelen != 2 && sizelen != 4
      raise ArgumentError.new("wrong number of arguments (given #{sizelen}, expected 2 or 4)")
    end

    row, col, xpixel, ypixel = size

    ws = LibC::Winsize.new
    if LibC.ioctl(self.fileno, LibC::TIOCGWINSZ, :pointer, ws.pointer) != 0
      raise SystemCallError.new("ioctl(TIOCGWINSZ)", FFI.errno)
    end

    ws[:ws_row] = row
    ws[:ws_col] = col
    ws[:ws_xpixel] = xpixel&.to_i || 0
    ws[:ws_ypixel] = ypixel&.to_i || 0

    if LibC.ioctl(self.fileno, LibC::TIOCSWINSZ, :pointer, ws.pointer) != 0
      raise SystemCallError.new("ioctl(TIOCSWINSZ)", FFI.errno)
    end
  end

  def iflush
    raise SystemCallError.new("tcflush(TCIFLUSH)", FFI.errno) unless LibC.tcflush(self.fileno, LibC::TCIFLUSH) == 0
  end

  def oflush
    raise SystemCallError.new("tcflush(TCOFLUSH)", FFI.errno) unless LibC.tcflush(self.fileno, LibC::TCOFLUSH) == 0
  end

  def ioflush
    raise SystemCallError.new("tcflush(TCIOFLUSH)", FFI.errno) unless LibC.tcflush(self.fileno, LibC::TCIOFLUSH) == 0
  end

  def cursor
    raw do
      syswrite "\e[6n"

      return nil if getbyte != 0x1b
      return nil if getbyte != ?[.ord

      num = 0
      result = []

      while b = getbyte
        c = b.to_i
        if c == ?;.ord
          result.push num
          num = 0
        elsif c >= ?0.ord && c <= ?9.ord
          num = num * 10 + c - ?0.ord
          #elsif opt && c == opt
        else
          last = c
          result.push num
          b = last.chr
          return nil unless b == ?R
          break
        end
      end

      result.map(&:pred)
    end
  end

  def cursor=(pos)
    pos = pos.to_ary if !pos.kind_of?(Array)

    raise "expected 2D coordinates" unless pos.size == 2

    x, y = pos
    syswrite(format("\x1b[%d;%dH", x + 1, y + 1))

    self
  end

  def cursor_down(n)
    raw do
      syswrite "\x1b[#{n}B"
    end

    self
  end

  def cursor_right(n)
    raw do
      syswrite "\x1b[#{n}C"
    end

    self
  end

  def cursor_left(n)
    raw do
      syswrite "\x1b[#{n}D"
    end

    self
  end

  def cursor_up(n)
    raw do
      syswrite "\x1b[#{n}A"
    end

    self
  end

  # TODO: Windows version uses "conin$" and "conout$" instead of /dev/tty
  def self.console(sym = nil, *args)
    raise TypeError, "expected Symbol, got #{sym.class}" unless sym.nil? || sym.kind_of?(Symbol)

    # klass = self == IO ? File : self
    if defined?(@console) # using ivar instead of hidden const as in MRI
      con = @console
      # MRI checks IO internals : (!RB_TYPE_P(con, T_FILE) || (!(fptr = RFILE(con)->fptr) || GetReadFD(fptr) == -1))
      if !con.kind_of?(File) || (con.kind_of?(IO) && (con.closed? || !FileTest.readable?(con)))
        remove_instance_variable :@console
        con = nil
      end
    end

    if sym
      if sym == :close
        if con
          con.close
          remove_instance_variable :@console if defined?(@console)
        end
        return nil
      end
    end

    if !con
      begin
        con = File.open('/dev/tty', 'r+')
      rescue
        return nil
      end

      con.sync = true
      @console = con
    end

    return con.send(sym, *args) if sym
    return con
  end
end
