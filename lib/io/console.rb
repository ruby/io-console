begin
  require "#{RUBY_VERSION[/\d+\.\d+/]}/io/console.so"
rescue LoadError
  require 'io/console.so'
end
