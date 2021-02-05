if RUBY_ENGINE == 'ruby' || RUBY_ENGINE == 'truffleruby'
  require_relative 'console.so'
else
  require_relative 'console/ffi/console'
end
