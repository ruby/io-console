if Gem.win_platform?
  begin
    require "#{RUBY_VERSION[/\d+\.\d+/]}/io/console.so"
  rescue LoadError
    require 'io/console.so'
  end
else
  require 'io/console.so'
end
