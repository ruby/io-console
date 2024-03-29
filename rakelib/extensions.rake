require "bundler/gem_tasks"

gemspec = Bundler::GemHelper.instance.gemspec
if gemspec.extensions.empty?
  warn "No extensions in #{gemspec.loaded_from}"
end

task :compile
extlibs = gemspec.extensions.map do |extconf|
  extension_dir = File.dirname(extconf)

  # Extract extension name passed to `create_makefile`.
  # Do not use %-literals other than simple quotes.
  extension_name = File.read(extconf)[/create_makefile\(? *(['"])(.*?)\1/, 2]

  build_dir = "#{ENV.fetch("BUILD_DIR", ".build")}/#{RUBY_VERSION}/#{RUBY_PLATFORM}"
  extlib = build_dir
  build_dir = "#{build_dir}/#{File.dirname(extension_name)}" if extension_name.include?("/")

  desc("The build directory for #{extension_name}")
  directory build_dir

  makefile = "#{build_dir}/Makefile"
  desc("Makefile in #{build_dir}")
  file makefile => "#{extension_dir}/depend" if File.exist?("#{extension_dir}/depend")
  file(makefile => extconf) {
    ruby("-C", build_dir, Pathname(extconf).relative_path_from(build_dir).to_s)
  } | build_dir

  so = "#{build_dir}/#{extension_name}.#{RbConfig::CONFIG['DLEXT']}"
  desc("Extension library: #{so}")
  file(so => [:force, makefile]) {MAKE[chdir: build_dir]}

  task :compile => so

  extlib
end

# HACK: Replace `:extlibs` in `libs` of tasks defined by
# `Rake::TestTask.new("test")` with the built extension directories.
Rake::Task["test"]&.actions&.each do |act|
  if (Rake::TestTask === (task = act.binding.receiver) and
      at = task.libs.find_index(:extlibs))
    task.libs[at, 1] = extlibs
  end
end

task :clean do
  extlibs.each {|build_dir|
    if File.exist?("#{build_dir}/Makefile")
      MAKE["clean", chdir: build_dir]
    end
  }
end
task :distclean do
  extlibs.each do |build_dir|
    if File.exist?("#{build_dir}/Makefile")
      MAKE["distclean", chdir: build_dir]
    end
  end
  extlibs.each do |build_dir|
    if File.directory?(build_dir)
      FileUtils.rmdir(build_dir, parents: true, verbose: true)
    end
  end
end
task clobber: :distclean
