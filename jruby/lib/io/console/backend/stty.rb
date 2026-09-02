# attempt to call stty; if failure, raise error
module IO::Console
  STTY = %w[/usr/bin/stty /bin/stty].find {|path| File.executable?(path)}
end

raise LoadError, "stty command not found" unless IO::Console::STTY

warn "io/console on JRuby shells out to stty for most operations" if $VERBOSE

class IO::Console::Mode
  STTY_PATTERNS = /
    (?<a>[a-z]\w*)\s(?:=\s(?:(?<n>\d+)|(?<c>\^.|.)|<undef>)|(?<n>\d+)(?:\s+\w+)?); |
    (?<n>\d+)\s+(?<a>[a-z]\w*); |
    (?<f>-)?(?<a>[a-z]\w*)(?=\s|$)
  /x
  private_constant :STTY_PATTERNS

  def initialize(saved, attrs)
    @saved = saved.chomp
    @attrs = {}
    attrs.scan(STTY_PATTERNS) do
      m = $~
      case attr = m[:a]
      when "echo"
        @attrs[attr.to_sym] = !m[:f]
      when "min", "time"
        @attrs[attr.to_sym] = m[:n]&.to_i
      when *%w[brkint icanon isig opost]
        @attrs[attr.to_sym] = !m[:f]
      end
    end
    @args = []
    @changes = {}
  end

  def initialize_copy(mode)
    super
    @attrs = @attrs.dup
    @saved = @saved.dup
    @args = @args.dup
    @changes = @changes.dup
  end

  def arguments
    [
      @saved,
      *@args,
      *@changes.flat_map {|a, v|
        case v
        when true
          a.to_s
        when false
          "-#{a}"
        when nil
        else
          [a.to_s, v.to_s]
        end
      },
    ]
  end

  def echo?
    @changes.fetch(:echo) {@attrs[:echo]}
  end
  alias echo echo?

  def echo=(echo)
    @changes[:echo] = echo
  end

  def raw(min: nil, time: nil, intr: nil)
    dup.raw!(min:, time:, intr:)
  end

  def raw!(min: nil, time: nil, intr: nil)
    @args << 'raw'
    self.min = min
    self.time = time
    %i[brkint isig opost].each {|a| @changes[a] = true} if intr
    self
  end

  def min
    @changes.fetch(:min) {@attrs[:min]}
  end

  def min=(min)
    @changes[:min] = (min || 1).to_i.clamp(0, 255)
  end

  def time
    @changes.fetch(:time) {@attrs[:time]}&.quo(10)
  end

  def time=(time)
    @changes[:time] = ((time || 0) * 10).to_i.clamp(0, 255)
  end

  private

  attr_reader :attrs, :saved, :args, :changes
end

# Non-Windows assumes stty command is available
class IO
  private def _io_console_stty(*args)
    # pre-check to catch non-tty filenos we can't stty against anyway
    raise Errno::ENOTTY, inspect if !tty?

    IO.pipe do |re, we|
      input = dup # workaround for JRuby
      IO.popen([Console::STTY, *args, in: input, err: we], &:read)
    ensure
      input&.close
      unless $?.success?
        we.close
        error = re.read
        case error
        when /Inappropriate ioctl for device/
          raise Errno::ENOTTY, inspect
        end
        raise "stty command failed: #{error.chomp}"
      end
    end
  end

  def raw(*, min: 1, time: nil, intr: nil)
    saved = console_mode
    self.console_mode = saved.raw(min:, time:, intr:)
    yield self
  ensure
    self.console_mode = saved if saved
  end

  def raw!(*, min: 1, time: nil, intr: nil)
    self.console_mode = console_mode.raw(min:, time:, intr:)
    self
  end

  def cooked(*)
    saved = _io_console_stty('-g')
    _io_console_stty('-raw')
    yield self
  ensure
    _io_console_stty(saved) if saved
  end

  def cooked!(*)
    _io_console_stty('-raw')
  end

  def echo=(echo)
    _io_console_stty(echo ? 'echo' : '-echo')
  end

  def echo?
    (_io_console_stty('-a') =~ / -echo /) ? false : true
  end

  def noecho
    saved = _io_console_stty('-g')
    _io_console_stty('-echo')
    yield self
  ensure
    _io_console_stty(saved) if saved
  end

  def console_mode
    Console::Mode.new(_io_console_stty('-g'), _io_console_stty('-a'))
  end

  def console_mode=(mode)
    _io_console_stty(*mode.arguments)
    mode
  end

  def winsize
    # Pattern for rows/columns; all systems may not return in these formats.
    match = /
      (?<rows>\d+)\s+rows;\s*(?<columns>\d+)\s+columns |
      rows\s+(?<rows>\d+);\s*columns\s+(?<columns>\d+)
    /x.match(_io_console_stty('-a'))
    [match[:rows].to_i, match[:columns].to_i]
  end

  def winsize=(size)
    size = size.to_ary unless size.kind_of?(Array)
    sizelen = size.size

    if sizelen != 2 && sizelen != 4
      raise ArgumentError, "wrong number of arguments (given #{sizelen}, expected 2 or 4)"
    end

    if sizelen == 4
      warn "stty io/console does not support pixel winsize"
    end

    row, col, _, _ = size

    _io_console_stty('rows', row.to_s, 'cols', col.to_s)
  end

  def iflush
  end

  def oflush
  end

  def ioflush
  end
end
