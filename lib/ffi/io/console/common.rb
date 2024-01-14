# Methods common to all backend impls
class IO
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
      if $stdin.isatty && $stdout.isatty
        begin
          con = File.open('/dev/tty', 'r+')
        rescue
          return nil
        end

        con.sync = true
      end

      @console = con
    end

    return con.send(sym, *args) if sym
    return con
  end

  def getch(*, **opts)
    raw(**opts) do
      getc
    end
  end

  def getpass(prompt = nil)
    wio = self == $stdin ? $stderr : self
    wio.write(prompt) if prompt
    begin
      str = nil
      noecho do
        str = gets
      end
    ensure
      puts($/)
    end
    str.chomp
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

  module GenericReadable
    def getch(*)
      getc
    end

    def getpass(prompt = nil)
      write(prompt) if prompt
      str = gets.chomp
      puts($/)
      str
    end
  end
end
