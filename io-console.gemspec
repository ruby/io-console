# -*- ruby -*-
_VERSION = IO.popen(%W[git -C #{__dir__} describe --tags], &:read)[/\A\d+(?:\.\d+)*/]
date = %w$Date::                           $[1]

Gem::Specification.new do |s|
  s.name = "io-console"
  s.version = _VERSION
  s.date = date
  s.summary = "Console interface"
  s.email = "nobu@ruby-lang.org"
  s.description = "add console capabilities to IO instances."
  s.required_ruby_version = ">= 2.2.0"
  s.homepage = "https://github.com/ruby/io-console"
  s.metadata["source_code_url"] = s.homepage
  s.authors = ["Nobu Nakada"]
  s.require_path = %[lib]
  s.files = %w[
    LICENSE.txt
    README.md
    ext/io/console/console.c
    ext/io/console/extconf.rb
    ext/io/console/win32_vk.inc
    lib/io/console.rb
    lib/io/console/size.rb
  ]
  s.extensions = %w[ext/io/console/extconf.rb]
  s.license = "BSD-2-Clause"

  s.add_development_dependency 'rake-compiler'
  s.add_development_dependency 'rake-compiler-dock', ">= 0.6.1"
end
