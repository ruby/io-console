source "https://rubygems.org"

# Specify your gem's dependencies in io-console.gemspec
gemspec

group :development do
  gem "bundler"
  gem "rake"
  gem "test-unit"
  gem "test-unit-ruby-core"
  gem 'rake-compiler'

  # RDoc 8 pulls in RBS 4, which attempts to build a native extension on JRuby.
  gem 'rdoc', (RUBY_ENGINE == 'jruby' ? '< 8' : nil)
end
