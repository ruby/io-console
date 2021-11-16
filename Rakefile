require "bundler/gem_tasks"
require "rake/testtask"

name = "io/console"

if RUBY_ENGINE == "ruby" || RUBY_ENGINE == "truffleruby"
  require 'rake/extensiontask'
  extask = Rake::ExtensionTask.new(name) do |x|
    x.lib_dir << "/#{RUBY_VERSION}/#{x.platform}"
  end
  task :test => :compile
end

Rake::TestTask.new(:test) do |t|
  if extask
    t.libs = [extask.lib_dir]
  end
  t.libs << "test/lib"
  t.ruby_opts << "-rhelper"
  t.test_files = FileList["test/**/test_*.rb"]
end

task :default => :test

task "build" => "build:java"

task "build:java" => "date_epoch"
