# attempt to call stty; if failure, raise error
`stty 2> /dev/null`
if $?.exitstatus != 0
  raise "stty command returned nonzero exit status"
end

warn "io/console on JRuby shells out to stty for most operations" if $VERBOSE

# Non-Windows assumes stty command is available
class IO
  if RbConfig::CONFIG['host_os'].downcase =~ /linux/ && File.exists?("/proc/#{Process.pid}/fd")
    protected def _io_console_stty(*args)
      _io_console_stty_error { `stty #{args.join(' ')} < /proc/#{Process.pid}/fd/#{fileno}` }
    end
  else
    protected def _io_console_stty(*args)
      _io_console_stty_error { `stty #{args.join(' ')}` }
    end
  end

  protected def _io_console_stty_error
    # pre-check to catch non-tty filenos we can't stty against anyway
    raise Errno::ENOTTY, inspect if !tty?

    result = yield

    case result
    when /Inappropriate ioctl for device/
      raise Errno.ENOTTY, inspect
    end

    result
  end

  def raw(*, min: 1, time: nil, intr: nil)
    saved = _io_console_stty('-g raw')
    yield self
  ensure
    _io_console_stty(saved)
  end

  def raw!(*)
    stty('raw')
  end

  def cooked(*)
    saved = _io_console_stty('-g', '-raw')
    yield self
  ensure
    _io_console_stty(saved)
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
    saved = _io_console_stty('-g', '-echo')
    yield self
  ensure
    _io_console_stty(saved)
  end

  # Not all systems return same format of stty -a output
  IEEE_STD_1003_2 = '(?<rows>\d+) rows; (?<columns>\d+) columns'
  UBUNTU = 'rows (?<rows>\d+); columns (?<columns>\d+)'

  def winsize
    match = _io_console_stty('-a').match(/#{IEEE_STD_1003_2}|#{UBUNTU}/)
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

    _io_console_stty("rows #{row} cols #{col}")
  end

  def iflush
  end

  def oflush
  end

  def ioflush
  end
end
