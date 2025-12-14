class << (helper = Bundler::GemHelper.instance)
  PATH = "ext/io/console/console.c"
  def update_gemspec
    File.open(PATH, "r+b") do |f|
      d = f.read
      if d.sub!(/^(IO_CONSOLE_VERSION\s*=\s*)".*"/) {$1 + gemspec.version.to_s.dump}
        f.rewind
        f.truncate(0)
        f.print(d)
      end
    end
  end

  def commit_bump
    sh(%W[git commit -m bump\ up\ to\ #{gemspec.version} #{PATH}])
  end

  def version=(v)
    gemspec.version = v
    update_gemspec
    commit_bump
  end

  def next_dev
    v = gemspec.version.segments
    if v.size > 4
      v[-1] = v[-1].succ
    else
      v[2] = v[2].succ if v.size == 3
      v[3..-1] = "dev.1"
    end
    Gem::Version.new(v.join("."))
  end

  def next_preview
    v = gemspec.version.segments
    if v[3] == "pre"
      v[-1] = v[-1].succ
    else
      v[3..-1] = "pre.1"
    end
    Gem::Version.new(v.join("."))
  end

  def next_release
    if gemspec.version.prerelease?
      gemspec.version.release
    else
      v = gemspec.version.segments[0, 3]
      v[-1] = v[-1].succ
      Gem::Version.new(v.join("."))
    end
  end

  def next_minor
    major, minor = gemspec.version.segments
    Gem::Version.new("#{major}.#{minor+1}.0")
  end

  def next_major
    major, = gemspec.version.segments
    Gem::Version.new("#{major+1}.0.0")
  end
end

desc "Bump to development"
task "bump:dev" do
  helper.version = helper.next_dev
end

desc "Bump to prerelease"
task "bump:pre" do
  helper.version = helper.next_preview
end

desc "Bump teeny version"
task "bump:teeny" do
  helper.version = helper.next_release
end

desc "Bump minor version"
task "bump:minor" do
  helper.version = helper.next_minor
end

desc "Bump major version"
task "bump:major" do
  helper.version = helper.next_major
end

desc "Bump teeny version"
task "bump" => "bump:teeny"

task "tag" do
  helper.__send__(:tag_version)
end
