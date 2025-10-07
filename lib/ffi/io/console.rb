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

case RbConfig::CONFIG['host_os']
when /darwin|openbsd|freebsd|netbsd|linux/i
  # If Linux or BSD, try to load the native version

  begin

    # Attempt to load the native Linux and BSD console logic
    require_relative 'console/native_console'

  rescue Exception => ex

    warn "failed to load native console support: #{ex}" if $VERBOSE

  else

    # Native ready.
    ready = true

  end

when /mswin|win32|ming/i
  # If Windows, stty is not possible, always use the stub version

  ready = false

end

if ready.nil?
  # Native is not ready, try to use stty

  begin

    require_relative 'console/stty_console'
    ready = true

  rescue Exception => ex2

    warn "failed to load stty console support: #{ex2}" if $VERBOSE
    ready = false

  end
end

unless ready
  # If still not ready, just use stubbed version

  require_relative 'console/stub_console'
end
