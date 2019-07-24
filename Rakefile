require "bundler/gem_tasks"
require "rake/testtask"

name = "io/console"
specfile = name.tr("/", "-")+".gemspec"

PLATFORMS = %w[x86-mingw32 x64-mingw32]
VERSIONS = %w[2.4.0 2.5.0 2.6.0]

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "test/lib"
  t.libs << "lib"
  t.test_files = FileList["test/**/test_*.rb"]
end

require 'rake/extensiontask'
spec = eval(File.read(specfile), nil, specfile)
spec.files.delete_if {|n| %r'\Aext/' =~ n}
spec.extensions.clear
spec.require_paths.insert(0, *%w[stub])
Rake::ExtensionTask.new(name, spec) do |ext|
  ext.cross_compile = true
  ext.cross_platform = PLATFORMS
  ext.cross_compiling do |s|
    s.files.concat VERSIONS.map {|v| "lib/#{v[/\A\d+\.\d+/]}/#{name}.so"}
  end
end

desc "Compile binaries for mingw platform using rake-compiler-dock"
task 'build:mingw' do
  require 'rake_compiler_dock'
  RakeCompilerDock.sh "bundle && rake cross native gem RUBY_CC_VERSION=#{VERSIONS.join(':')}"
end

task 'release:rubygem_push' => 'release:rubygem_push:mingw'
desc 'Push fat binary gems for mingw platform'
task 'release:rubygem_push:mingw' do
  pkgs = PLATFORMS.map {|platform| "pkg/#{spec.full_name}-#{platform}.gem"}
  Bundler::GemHelper.instance.instance_eval do
    if gem_push?
      pkgs.each do |pkg|
        Bundler.ui.confirm "Pushing #{pkg}"
        rubygem_push(pkg)
      end
    end
  end
end

task :default => [:compile, :test]
