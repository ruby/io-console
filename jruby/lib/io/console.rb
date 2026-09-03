# This implementation of io/console is a little hacky. It shells out to `stty`
# for most operations, which does not work on Windows, in secured environments,
# and so on. In addition, because on Java 6 we can't actually launch
# subprocesses with tty control, stty will not actually manipulate the
# controlling terminal.
#
# For platforms where shelling to stty does not work, most operations will
# just be pass-throughs. This allows them to function, but does not actually
# change any tty flags.
#
# Finally, since we're using stty to shell out, we can only manipulate stdin/
# stdout tty rather than manipulating whatever terminal is actually associated
# with the IO we're calling against. This will produce surprising results if
# anyone is actually using io/console against non-stdio ttys...but that case
# seems like it would be pretty rare.
#
# Note: we are incorporating this into 1.7.0 since RubyGems uses io/console
# when pushing gems, in order to mask the password entry. Worst case is that
# we don't actually disable echo and the password is shown...we will try to
# do a better version of this in 1.7.1.

require 'rbconfig'

require_relative 'console/version'
require_relative 'console/common'

class IO
  module Console
    class Mode
      VERSION = Console::VERSION
      deprecate_constant :VERSION
    end
  end

  ConsoleMode = Console::Mode
  deprecate_constant :ConsoleMode
end

backends = []
ENV["IO_CONSOLE_BACKEND"]&.tap do |be|
  backends.concat(be.split(",").map {|b| b.split(":")})
end&.first ||
# If Linux or BSD, try to load the native version
case RbConfig::CONFIG['host_os']
when /darwin|openbsd|freebsd|netbsd/i
  backends << %w[ffi/termios bsd] << %w[stty]
when /linux/i
  backends << %w[ffi/termios linux] << %w[stty]
when /mswin|win32|ming/i
  require_relative 'console/constants/windows'
  require_relative 'console/backend/ffi/windows'
  return
else
  backends << %w[stty]
end

return if backends.any? do |backend, constants|
  require_relative "console/constants/#{constants}" if constants
  require_relative "console/backend/#{backend}"
rescue Exception => ex
  warn "failed to load #{backend.split('/', 2).first} console support: #{ex}" if $VERBOSE
else
  true
end

# If still not ready, just use stubbed version
require_relative 'console/backend/stub'
