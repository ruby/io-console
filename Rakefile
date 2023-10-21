require "bundler/gem_tasks"
require "rake/testtask"
require "rdoc/task"

name = "io/console"

if RUBY_ENGINE == "ruby" || RUBY_ENGINE == "truffleruby"
  require 'rake/extensiontask'
  extask = Rake::ExtensionTask.new(name) do |x|
    x.lib_dir.sub!(%r[(?=/|\z)], "/#{RUBY_VERSION}/#{x.platform}")
  end
  task :test => :compile
end

Rake::TestTask.new(:test) do |t|
  if extask
    t.libs = ["lib/#{RUBY_VERSION}/#{extask.platform}"]
  end
  t.libs << "test/lib"
  t.ruby_opts << "-rhelper"
  t.test_files = FileList["test/**/test_*.rb"]
end

RDoc::Task.new

task :default => :test

task "build" => "build:java"

task "build:java" => "date_epoch"
