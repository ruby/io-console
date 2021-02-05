require "bundler/gem_tasks"
require "rake/testtask"

name = "io/console"
helper = Bundler::GemHelper.instance

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "test/lib"
  t.libs << "lib"
  t.ruby_opts << "-rhelper"
  t.test_files = FileList["test/**/test_*.rb"]
end

if RUBY_ENGINE == "ruby" || RUBY_ENGINE == "truffleruby"
  require 'rake/extensiontask'
  Rake::ExtensionTask.new(name)
  task :test => :compile
end

task :default => :test

task "build" => "date_epoch"
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

task "date_epoch" do
  ENV["SOURCE_DATE_EPOCH"] = IO.popen(%W[git -C #{__dir__} log -1 --format=%ct], &:read).chomp
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

def helper.update_gemspec
  path = "#{__dir__}/#{gemspec.name}.gemspec"
  File.open(path, "r+b") do |f|
    if (d = f.read).sub!(/^(_VERSION\s*=\s*)".*"/) {$1 + gemspec.version.to_s.dump}
      f.rewind
      f.truncate(0)
      f.print(d)
    end
  end
end

def helper.commit_bump
  sh(%W[git -C #{__dir__} commit -m bump\ up\ to\ #{gemspec.version}
        #{gemspec.name}.gemspec])
end

def helper.version=(v)
  gemspec.version = v
  update_gemspec
  commit_bump
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
