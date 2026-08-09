require 'ffi'

module IO::Console::Windows
  module Native
    extend FFI::Library
    ffi_convention :stdcall
    ffi_lib 'kernel32'
    attach_function :GetStdHandle, [:int32], :pointer
    attach_function :GetConsoleMode, [:pointer, :pointer], :int
    attach_function :SetConsoleMode, [:pointer, :uint32], :int
    attach_function :WaitForSingleObject, [:pointer, :uint32], :uint32
    attach_function :ReadConsoleInputW,
                    [:pointer, :pointer, :uint32, :pointer], :int
    attach_function :GetFileType, [:pointer], :uint32
    attach_function :GetFileInformationByHandleEx,
                    [:pointer, :int, :pointer, :uint32], :int
    attach_function :GetConsoleScreenBufferInfo, [:pointer, :pointer], :int
    attach_function :SetConsoleCursorPosition, [:pointer, :uint32], :int
    attach_function :FillConsoleOutputCharacterW,
                    [:pointer, :uint16, :uint32, :uint32, :pointer], :int
    attach_function :FillConsoleOutputAttribute,
                    [:pointer, :uint16, :uint32, :uint32, :pointer], :int
    attach_function :GetConsoleCursorInfo, [:pointer, :pointer], :int
    attach_function :SetConsoleCursorInfo, [:pointer, :pointer], :int
  end

  module CRT
    extend FFI::Library
    ffi_convention :cdecl
    ffi_lib 'msvcrt'
    attach_function :_kbhit, [], :int
  end

  GetStdHandle = Native.method(:GetStdHandle)
  GetConsoleMode = Native.method(:GetConsoleMode)
  SetConsoleMode = Native.method(:SetConsoleMode)
  WaitForSingleObject = Native.method(:WaitForSingleObject)
  ReadConsoleInputW = Native.method(:ReadConsoleInputW)
  GetFileType = Native.method(:GetFileType)
  GetFileInformationByHandleEx = Native.method(:GetFileInformationByHandleEx)
  GetConsoleScreenBufferInfo = Native.method(:GetConsoleScreenBufferInfo)
  SetConsoleCursorPosition = Native.method(:SetConsoleCursorPosition)
  FillConsoleOutputCharacter = Native.method(:FillConsoleOutputCharacterW)
  FillConsoleOutputAttribute = Native.method(:FillConsoleOutputAttribute)
  GetConsoleCursorInfo = Native.method(:GetConsoleCursorInfo)
  SetConsoleCursorInfo = Native.method(:SetConsoleCursorInfo)
  Kbhit = CRT.method(:_kbhit)

  INPUT_HANDLE = GetStdHandle.call(STD_INPUT_HANDLE)
  OUTPUT_HANDLE = GetStdHandle.call(STD_OUTPUT_HANDLE)

  module_function

  def handle(io)
    io.equal?(STDIN) ? INPUT_HANDLE : OUTPUT_HANDLE
  end

  def console_mode(io)
    buffer = "\0" * 4
    raise SystemCallError, 'GetConsoleMode' if GetConsoleMode.call(handle(io), buffer) == 0
    buffer.unpack1('L')
  end

  def set_console_mode(io, mode)
    raise SystemCallError, 'SetConsoleMode' if SetConsoleMode.call(handle(io), mode) == 0
  end

  def screen_buffer_info(io)
    buffer = "\0" * 22
    raise SystemCallError, 'GetConsoleScreenBufferInfo' if GetConsoleScreenBufferInfo.call(handle(io), buffer) == 0
    buffer.unpack('s9')
  end

  def coordinate(x, y)
    (y & 0xffff) << 16 | (x & 0xffff)
  end
end

module IO::Console::Windows::TTY
  def tty?(*types)
    return super() if types.empty?

    default = msys = cygwin = false
    types.each do |type|
      case type
      when nil
        default = true
      when :any
        default = msys = cygwin = true
      when :msys
        msys = true
      when :cygwin
        cygwin = true
      when Symbol
        raise ArgumentError, "unknown tty type: #{type.inspect}"
      else
        raise TypeError, "expected Symbol, got #{type.class}"
      end
    end

    return true if default && super()
    (msys || cygwin) && msys_tty?(msys, cygwin)
  end
  alias isatty tty?

  private def msys_tty?(msys, cygwin)
    windows = IO::Console::Windows
    handle = windows.handle(self)
    return false unless windows::GetFileType.call(handle) == 3
    buffer = "\0" * 1024
    return false if windows::GetFileInformationByHandleEx.call(handle, 2, buffer, 1022) == 0
    length = buffer.unpack1('L')
    name = buffer[4, length].encode(Encoding::UTF_8, Encoding::UTF_16LE, invalid: :replace)
    return false unless (msys && name.start_with?('\\msys-')) || (cygwin && name.start_with?('\\cygwin-'))
    name.include?('-pty')
  end
end

IO.prepend(IO::Console::Windows::TTY)

class IO::ConsoleMode
  def initialize(mode)
    @mode = mode
  end

  def virtual_terminal_processing?
    @mode & IO::Console::Windows::ENABLE_VIRTUAL_TERMINAL_PROCESSING != 0
  end

  def virtual_terminal_processing=(enabled)
    set_flag(IO::Console::Windows::ENABLE_VIRTUAL_TERMINAL_PROCESSING, enabled)
  end

  def wrap_at_eol_output?
    @mode & IO::Console::Windows::ENABLE_WRAP_AT_EOL_OUTPUT != 0
  end

  def wrap_at_eol_output=(enabled)
    set_flag(IO::Console::Windows::ENABLE_WRAP_AT_EOL_OUTPUT, enabled)
  end

  private def set_flag(flag, enabled)
    enabled ? @mode |= flag : @mode &= ~flag
    self
  end

  private def to_i
    @mode
  end
end

class IO
  def console_mode
    IO::ConsoleMode.new(IO::Console::Windows.console_mode(self))
  end

  def console_mode=(mode)
    IO::Console::Windows.set_console_mode(self, mode.__send__(:to_i))
    mode
  end

  def input_pending?
    windows = IO::Console::Windows
    return windows::Kbhit.call != 0 if windows::GetConsoleMode.call(windows.handle(self), "\0" * 4) != 0
    respond_to?(:wait_readable) && !!wait_readable(0)
  end

  def console_input_events(max_events = 1, timeout: nil)
    raise ArgumentError, 'max_events must be positive' unless max_events > 0
    raise ArgumentError, 'time interval must not be negative' if timeout && timeout < 0

    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout if timeout
    loop do
      wait = deadline && deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return [] if wait && wait <= 0
      milliseconds = wait ? [[(wait * 1000).ceil, 100].min, 0].max : 100
      windows = IO::Console::Windows
      result = windows::WaitForSingleObject.call(windows.handle(self), milliseconds)
      break if result == windows::WAIT_OBJECT_0
      return [] if result != windows::WAIT_TIMEOUT
      return [] if deadline && Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    end

    records = "\0" * 20 * max_events
    count = "\0" * 4
    windows = IO::Console::Windows
    if windows::ReadConsoleInputW.call(windows.handle(self), records, max_events, count) == 0
      raise SystemCallError, 'ReadConsoleInputW'
    end
    count.unpack1('L').times.map do |index|
      record = records[index * 20, 20]
      event_type = record.unpack1('S')
      case event_type
      when 1
        key_down, repeat_count, virtual_key_code, virtual_scan_code,
          unicode_char, control_key_state = record[4, 16].unpack('LS4L')
        {
          type: :key, key_down: key_down != 0, repeat_count: repeat_count,
          virtual_key_code: virtual_key_code, virtual_scan_code: virtual_scan_code,
          unicode_char: unicode_char, control_key_state: control_key_state,
        }
      when 2
        x, y, button_state, control_key_state, event_flags = record[4, 16].unpack('s2L3')
        {type: :mouse, position: [y, x], button_state: button_state,
         control_key_state: control_key_state, event_flags: event_flags}
      when 4
        x, y = record[4, 4].unpack('s2')
        {type: :window_buffer_size, size: [y, x]}
      when 8
        {type: :menu, command_id: record[4, 4].unpack1('L')}
      when 16
        {type: :focus, set_focus: record[4, 4].unpack1('L') != 0}
      else
        {type: event_type}
      end
    end
  end

  def winsize
    width, _, _, _, _, _, top, _, bottom = IO::Console::Windows.screen_buffer_info(self)
    [bottom - top + 1, width]
  end

  def cursor
    _, _, x, y, _, _, top, = IO::Console::Windows.screen_buffer_info(self)
    [y - top, x]
  end

  def goto(row, column)
    windows = IO::Console::Windows
    _, _, _, _, _, _, top, = windows.screen_buffer_info(self)
    position = windows.coordinate(column, row + top)
    raise SystemCallError, 'SetConsoleCursorPosition' if windows::SetConsoleCursorPosition.call(windows.handle(self), position) == 0
    self
  end

  def goto_column(column)
    row, = cursor
    goto(row, column)
  end

  def erase_line(mode)
    raise ArgumentError, 'invalid line erase mode' unless (0..2).cover?(mode)
    windows = IO::Console::Windows
    width, _, x, y, attributes, = windows.screen_buffer_info(self)
    start = mode == 0 ? x : 0
    length = mode == 0 ? width - x : mode == 1 ? x + 1 : width
    position = windows.coordinate(start, y)
    written = "\0" * 4
    windows::FillConsoleOutputCharacter.call(windows.handle(self), 0x20, length, position, written)
    windows::FillConsoleOutputAttribute.call(windows.handle(self), attributes, length, position, written)
    self
  end

  def clear_screen
    windows = IO::Console::Windows
    width, _, _, _, attributes, _, top, _, bottom = windows.screen_buffer_info(self)
    length = width * (bottom - top + 1)
    position = windows.coordinate(0, top)
    written = "\0" * 4
    windows::FillConsoleOutputCharacter.call(windows.handle(self), 0x20, length, position, written)
    windows::FillConsoleOutputAttribute.call(windows.handle(self), attributes, length, position, written)
    windows::SetConsoleCursorPosition.call(windows.handle(self), position)
    self
  end

  def hide_cursor
    set_cursor_visibility(false)
  end

  def show_cursor
    set_cursor_visibility(true)
  end

  private def set_cursor_visibility(visible)
    info = "\0" * 8
    windows = IO::Console::Windows
    handle = windows.handle(self)
    raise SystemCallError, 'GetConsoleCursorInfo' if windows::GetConsoleCursorInfo.call(handle, info) == 0
    size, = info.unpack('L2')
    info = [size, visible ? 1 : 0].pack('L2')
    raise SystemCallError, 'SetConsoleCursorInfo' if windows::SetConsoleCursorInfo.call(handle, info) == 0
    self
  end

end
