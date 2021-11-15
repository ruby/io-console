if RUBY_ENGINE == 'ruby' || RUBY_ENGINE == 'truffleruby'
  raise LoadError, 'loading unexpected file'
else
  require_relative 'console/ffi/console'
end
