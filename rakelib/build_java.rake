helper = Bundler::GemHelper.instance

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
