require "bundler/gem_tasks"
require "rake/testtask"
require "rdoc/task"

name = "io/console"

gemspec = Bundler::GemHelper.instance.gemspec

if RUBY_ENGINE == "ruby" || RUBY_ENGINE == "truffleruby"
  require "ruby-core/extensiontask"
  extask = RubyCore::ExtensionTask.new(gemspec)
  task :test => :compile
end

ffi_version_file = "lib/ffi/#{name}/version.rb"
task ffi_version_file => "#{name.tr('/', '-')}.gemspec" do |t|
  version = <<~RUBY
    class IO::ConsoleMode
      VERSION = "#{gemspec.version}"
    end
  RUBY
  unless (File.read(t.name) rescue nil) == version
    File.binwrite(t.name, version)
  end
end

task :build => ffi_version_file

Rake::TestTask.new(:test) do |t|
  t.libs.concat(extask.libs) if extask
  t.libs << "test/lib"
  t.ruby_opts << "-rhelper"
  t.options = "--ignore-name=TestIO_Console#test_bad_keyword" if RUBY_ENGINE == "jruby"
  t.test_files = FileList["test/**/test_*.rb"]
end

RDoc::Task.new

task :default => :test

task "build" => "build:java"

task "build:java" => "date_epoch"

task "coverage" do
  cov = []
  e = IO.popen([FileUtils::RUBY, "-S", "rdoc", "-C"], &:read)
  e.scan(/^ *# in file (?<loc>.*)\n *(?<code>.*)|^ *(?<code>.*\S) *# in file (?<loc>.*)/) do
    cov << "%s: %s\n" % $~.values_at(:loc, :code)
  end
  cov.sort!
  puts cov
end
