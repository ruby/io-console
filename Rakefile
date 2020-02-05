require "bundler/gem_tasks"
require "rake/testtask"

name = "io/console"
specfile = name.tr("/", "-")+".gemspec"
spec = eval(File.read(specfile), nil, specfile)

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "test/lib"
  t.libs << "lib"
  t.ruby_opts << "-rhelper"
  t.test_files = FileList["test/**/test_*.rb"]
end

require 'rake/extensiontask'
Rake::ExtensionTask.new(name)

task :default => [:compile, :test]

task "build" => "date_epoch"

java_pkg = nil
task 'build:java' => 'date_epoch' do |t|
  file_name = "#{spec.full_name}-java.gem"
  gem_command = ENV["GEM_COMMAND"]
  gem_command &&= gem_command.shellsplit
  Bundler::GemHelper.instance.instance_eval do
    sh([*(gem_command || "gem"), "build", "-V", specfile, "--", "--platform=java"]) do
      FileUtils.mkdir_p("pkg")
      FileUtils.mv(file_name, "pkg")
      Bundler.ui.confirm "#{spec.name} #{spec.version} built to pkg/#{file_name}."
    end
    java_pkg = File.join("pkg", file_name)
  end
end

task 'release:rubygem_push' => 'release:rubygem_push:java'
desc 'Push binary gems for Java platform'
task 'release:rubygem_push:java' => 'build:java' do
  Bundler::GemHelper.instance.instance_eval do
    if gem_push?
      Bundler.ui.confirm "Pushing #{java_pkg}"
      rubygem_push(java_pkg)
    end
  end
end

task "date_epoch" do
  ENV["SOURCE_DATE_EPOCH"] = IO.popen(%W[git -C #{__dir__} log -1 --format=%ct], &:read)
end

helper = Bundler::GemHelper.instance
def helper.version=(v)
  gemspec.version = v
  tag_version
end
major, minor, teeny = helper.gemspec.version.segments

task "bump:teeny" do
  helper.version = Gem::Version.new("#{major}.#{minor}.#{teeny+1}")
end

task "bump:minor" do
  helper.version = Gem::Version.new("#{major}.#{minor+1}.0")
end

task "bump:major" do
  helper.version = Gem::Version.new("#{major+1}.0.0")
end

task "bump" => "bump:teeny"
