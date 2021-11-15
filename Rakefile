require "bundler/gem_tasks"
require "rake/testtask"

name = "io/console"
helper = Bundler::GemHelper.instance

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

task :sync_tool do
  require 'fileutils'
  FileUtils.cp "../ruby/tool/lib/core_assertions.rb", "./test/lib"
  FileUtils.cp "../ruby/tool/lib/envutil.rb", "./test/lib"
  FileUtils.cp "../ruby/tool/lib/find_executable.rb", "./test/lib"
end

task :default => :test

task "build" => "build:java"

java_pkg = nil
task 'build:java' => 'date_epoch' do |t|
  java_pkg = helper.build_java_gem
end

task 'release:rubygem_push' => 'release:rubygem_push:java'
desc 'Push binary gems for Java platform'
task 'release:rubygem_push:java' => 'build:java' do
  helper.push_gem(java_pkg)
end

def helper.build_java_gem
  file_name = nil
  sh([*gem_command, "build", "-V", "--platform=java", spec_path]) do
    file_name = built_gem_path
    pkg = File.join(base, "pkg")
    FileUtils.mkdir_p(pkg)
    FileUtils.mv(file_name, pkg)
    file_name = File.basename(file_name)
    Bundler.ui.confirm "#{name} #{version} built to pkg/#{file_name}."
    file_name = File.join(pkg, file_name)
  end
  file_name
end

def helper.push_gem(path)
  if gem_push?
    Bundler.ui.confirm "Pushing #{path}"
    rubygem_push(path)
  end
end
