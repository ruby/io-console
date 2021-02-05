if RUBY_ENGINE == 'ruby'
  require_relative 'console.so'
else
  require_relative 'console/ffi/console'
end
