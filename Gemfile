source "https://rubygems.org"

# Specify your gem's dependencies in io-console.gemspec
gemspec

group :development do
  gem "bundler"
  gem "rake"
  gem "rdoc"

  # rdoc 8 depends on rbs, which has no java platform gem before 4.1.0.pre.2.
  # See https://github.com/ruby/rdoc/issues/1746
  gem 'rbs', '>= 4.1.0.pre.2' if RUBY_PLATFORM == 'java'

  gem "test-unit"
  gem "test-unit-ruby-core"
  gem 'rake-compiler'
end
