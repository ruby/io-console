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
