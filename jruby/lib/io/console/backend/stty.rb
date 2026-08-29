# attempt to call stty; if failure, raise error
module IO::Console
  STTY = %w[/usr/bin/stty /bin/stty].find {|path| File.executable?(path)}
end

raise LoadError, "stty command not found" unless IO::Console::STTY

warn "io/console on JRuby shells out to stty for most operations" if $VERBOSE

class IO::Console::Mode
  def initialize(saved)
    @saved = saved
    @args = []
  end

  def initialize_copy(mode)
    super
    @saved = mode.__send__(:saved).dup
    @args = mode.__send__(:args).dup
  end

  def echo=(echo)
    @args << (echo ? 'echo' : '-echo')
    echo
  end

  def raw(min: 1, time: nil, intr: nil)
    dup.raw!(min:, time:, intr:)
  end

  def raw!(min: 1, time: nil, intr: nil)
    @args << 'raw'
    @args.push('min', min.to_s) if min && min >= 0
    @args.push('time', ((time || 0) * 10).to_i.to_s)
    @args.concat(%w[brkint isig opost]) if intr
    self
  end

  private

  attr_reader :saved, :args
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
    Console::Mode.new(_io_console_stty('-g').chomp)
  end

  def console_mode=(mode)
    _io_console_stty(mode.__send__(:saved), *mode.__send__(:args))
    mode
  end

  # Not all systems return same format of stty -a output
  IEEE_STD_1003_2 = '(?<rows>\d+) rows; (?<columns>\d+) columns'
  UBUNTU = 'rows (?<rows>\d+); columns (?<columns>\d+)'

  def winsize
    match = _io_console_stty('-a').match(/#{IEEE_STD_1003_2}|#{UBUNTU}/o)
    [match[:rows].to_i, match[:columns].to_i]
  end

  def winsize=(size)
    size = size.to_ary unless size.kind_of?(Array)
    sizelen = size.size

    if sizelen != 2 && sizelen != 4
      raise ArgumentError.new("wrong number of arguments (given #{sizelen}, expected 2 or 4)")
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
