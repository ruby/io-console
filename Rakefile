require "bundler/gem_tasks"
require "rake/testtask"
require "rdoc/task"

name = "io/console"

if RUBY_ENGINE == "ruby" || RUBY_ENGINE == "truffleruby"
  require 'rake/extensiontask'
  extask = Rake::ExtensionTask.new(name) do |x|
    x.lib_dir.sub!(%r[(?:\A|/)\Klib(?=/|\z)], ".libs/#{RUBY_VERSION}/#{x.platform}")
  end
  task :test => :compile
end

jruby_version_file = "jruby/lib/#{name}/version.rb"
task jruby_version_file => "#{name.tr('/', '-')}.gemspec" do |t|
  version = <<~RUBY
    class IO
      module Console
        VERSION = "#{Bundler::GemHelper.instance.gemspec.version}"
      end
    end
  RUBY
  unless (File.read(t.name) rescue nil) == version
    File.binwrite(t.name, version)
  end
end

task :build => jruby_version_file
task :test => jruby_version_file if RUBY_ENGINE == "jruby"

Rake::TestTask.new(:test) do |t|
  if extask
    t.libs = [extask.lib_dir.chomp("/"+File.dirname(name))]
  elsif RUBY_ENGINE == "jruby"
    t.libs.unshift "jruby/lib"
  end
  t.libs << "test/lib"
  t.ruby_opts << "-rhelper"
  t.test_files = FileList["test/**/test_*.rb"]
end

RDoc::Task.new

task :default => :test

task "build" => %w[rdoc:coverage build:java]

task "build:java" => "date_epoch"

# Keep RDoc::Task's coverage check from exiting the Rake process.
coverage_task = Rake::Task["rdoc:coverage"].actions.shift
task "rdoc:coverage" do |*t|
  coverage_task.call(*t)
rescue SystemExit => exit
  raise "RDoc incomplete" unless exit.success?
end

task "coverage" do
  cov = []
  e = IO.popen([FileUtils::RUBY, "-S", "rdoc", "-C", "--all"], &:read)
  e.scan(/^ *(?:# in file (?<loc>.*)\n *(?<code>.*)|(?<code>.*\S) *# in file (?<loc>.*)|(?<code>\S+) (?<loc>\S+:\d+))/) do
    cov << "%s: %s\n" % $~.values_at(:loc, :code)
  end
  cov.sort!
  puts cov
  raise "RDoc incomplete" unless $?.success?
end
